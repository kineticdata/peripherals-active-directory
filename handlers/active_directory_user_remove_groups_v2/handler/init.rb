# Add the dependencies file to require vendor libs
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ActiveDirectoryUserRemoveGroupsV2
  # Prepare for execution by configuring the initial LDAP configuration, 
  # initializing Hash objects for necessary values, and validate the present
  # state.  This method sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input XML.
  # * @info_values - A Hash of task definition info item names to values.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @search_by - Determines the attribute to search for the user.
  # * @group_names - A list of groups to add to the user.
  #
  # ==== Parameters
  # * +input+ - The String of Xml that was built by evaluating the node.xml
  #   handler template.
  def initialize(input)
    # Construct an xml document to extract the parameters from the input string
    @input_document = REXML::Document.new(input)

    # Hash to hold the task info values
    @info_values = {}

    # Load the task info values
    REXML::XPath.each(@input_document,"/handler/infos/info") { |item|
    @info_values[item.attributes['name']] = item.text }

    # Create the ldap object to interact with the active directory server
    @ldap = Net::LDAP.new(
      :host => @info_values['host'],
      :port => @info_values['port'],
      :auth => {
        :method => :simple,
        :username => @info_values['username'],
        :password => @info_values['password']
      }
    )

    # Determine if debug logging is enabled.
    @debug_logging_enabled = @info_values['enable_debug_logging'] == 'Yes'
    if @debug_logging_enabled
      puts("Debug logging enabled...")
      puts("Connecting to #{@info_values['host']}:#{@info_values['port']} as #{@info_values['username']}.")
      puts("Using #{@info_values['base']} for the base of the directory tree.")
    end

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.each(@input_document, '/handler/parameters/parameter') { |node|
      @parameters[node.attributes['name']] = node.text
    }
    puts("Parameters: #{@parameters.inspect}") if @debug_logging_enabled

    # First locate the user entry if search by is User Logon, determine if UPN
    # suffix is present , then Set the @search_by to the actual attribute name 
    # for the search filter
    if @parameters['search_by'] == "User Logon"
      if @parameters['search_value'].include? '@'
        @search_by = 'userprincipalname'
      else
        @search_by = 'samaccountname'
      end
    elsif @parameters['search_by'] == "Full Name"
      @search_by = 'cn'
    elsif @parameters['search_by'] == "Email Address"
      @search_by = 'mail'
    elsif @parameters['search_by'] == "Distinguished Name"
      @search_by = 'distinguishedName'
    else
      raise "Unknown search attribute for user: #{@parameters['search_by']}"
    end

    # Create an array of group names to add to the user by splitting the
    # 'groups' parameter on any combination of spaces followed by a comma
    # followed by any number of spaces.
    @group_names = @parameters['groups'].split(%r{\s*,\s*})
  end
 
  # Searches for the user in the Active Directory server based on the search 
  # parameters starting with a filter for organizationalPerson, then removes the
  # user as a member of the specified groups.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute()
    # If we are successful in authenticating using the active directory
    # server and credentials specified by the task info values.
    if @ldap.bind
      # Build a filter to search by
      filter = Net::LDAP::Filter.eq( "objectclass", "organizationalPerson" )
      # Add the search value (attribute) to the filter for the search
      unless @parameters['search_value'].nil?
        filter = filter & Net::LDAP::Filter.eq(@search_by, @parameters['search_value'])
      end

      # Search operation - return result is set to true so that an array is
      # returned (to determine if search matches more than one entry)
      user_entries = @ldap.search(
        :base => @info_values['base'],
        :filter => filter,
        :size => 2,
        :return_result => true
       )

      # Raise an exception if there was a problem with the call
      unless @ldap.get_operation_result.code == 0
        raise @ldap.get_operation_result.message
      end

      # Raise exception if search did not return 1 entry
      if user_entries.length < 1
        raise "User not found when searching by #{@search_by} for: #{@parameters['search_value']}"
      elsif user_entries.length > 1
        raise "Search matched more than one entry when searching by #{@search_by} for: #{@parameters['search_value']}"
      end

      # Determine the users distinguished name
      user_dn = user_entries.first.dn
      puts "Retrieved User: #{user_dn}" if @debug_logging_enabled

      # For each of the group names
      groups = @group_names.inject({}) do |hash, group_name|
        # Initialize the group name
        hash[group_name] = nil
        # Build a filter to retrieve the group entries
        filter = Net::LDAP::Filter.eq( "objectclass", "group" ) & Net::LDAP::Filter.eq( "cn", group_name )
        # Search for each of the groups
        @ldap.search(
          :base => "#{@info_values['base']}",
          :filter => filter,
          :return_result => false
        ) {|entry| hash[group_name] = entry }
        # Return the hash to be used with the remaining inject calls
        hash
      end

      # Determine if there were any missing groups
      missing_groups = Hash[groups.select {|key, value| value.nil?}]
      # If there was at least 1 missing group
      if missing_groups.length > 0
        # Raise an error
        raise "Unable to locate the following groups: #{missing_groups.keys.join(', ')}"
      end

      # If debug logging is enabled
      if @debug_logging_enabled
        # Log the retrieved group information
        puts "Retrieved Groups:"
        groups.each do |name, group|
          puts "  #{name}: #{group.dn}"
        end
      end

      # Initialize any errors that occurred
      errors = {}
      # For each of the groups
      groups.each do |name, entry|
        # Attempt to remove the user from the group
        @ldap.modify(:dn => entry.dn, :operations => [[:delete, :member, [user_dn]]])

        # Log the results
        puts "Result for #{name}: #{@ldap.get_operation_result.message}" if @debug_logging_enabled

        # Add an error for the group name if the query was not successful
        unless @ldap.get_operation_result.code == 0
          errors.merge!(name => @ldap.get_operation_result.error_message)
        end
      end

      # If there were any errors
      if errors.length > 0
        # Initialize the error message string
        error_string = "There were problems removing the user with a " <<
          "#{@parameters['search_by']} of #{@parameters['search_value']} from " <<
          "the following groups: #{errors.keys.join(', ')}"
        # Add a specific error message for each of the failed groups
        errors.each do |group_name, error|
          error_string << "\n    #{groups[group_name].dn}: #{error.to_s.inspect}"
        end
        # Add in a list of groups successfully removed
        error_string << "\n  The following groups were successfully removed: " <<
          "#{(@group_names - errors.keys).join(', ')}"
        # Raise the exception
        raise error_string
      end
    # If authentication of the ldap session failed
    else
      # Raise an error
      raise "Directory authentication failed for #{@info_values['host']}: #{@ldap.get_operation_result}"
    end

    # Build, log, and return the results
    results = '<results/>'
    puts("Results: \n#{results}") if @debug_logging_enabled
	  return results
  end

  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end

  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}

end