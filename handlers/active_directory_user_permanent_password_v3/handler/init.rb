# Add the dependencies file to require vendor libs
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ActiveDirectoryUserPermanentPasswordV2
  # Load the LDAP bind information, build Hash objects for necessary values,
  # and validate the present state.  This method sets the following instance
  # variables:
  # * @input_document - A REXML::Document object that represents the input XML.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @info_values - A Hash of task definition info item names to values.
  # * @search_by - A String representing the attribute name to search by.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * +input+ - The String of Xml that was built by evaluating the node.xml
  #   handler template.
  def initialize(input)
    # Construct an xml document to extract the parameters from the input string
    @input_document = REXML::Document.new(input)

    # Retrieve the credentials and configuration values supplied by the task
    # info items.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") { |item|
      @info_values[item.attributes['name']] = item.text
    }

    # Determine if debug logging is enabled.
    @debug_logging_enabled = @info_values['enable_debug_logging'] == 'Yes'
    if @debug_logging_enabled
      puts("Debug logging enabled...")
      puts("Connecting to #{@info_values['host']}:#{@info_values['port']} as #{@info_values['username']}.")
      puts("Using #{@info_values['base']} for the base of the directory tree.")
    end

    # Initialize the Net::LDAP object with the credentials - have to use
    # encryption since we are sending a password
    @ldap = Net::LDAP.new(
      :host => @info_values['host'],
      :port => @info_values['port'],
      :auth => {
        :method => :simple,
        :username => @info_values['username'],
        :password => @info_values['password']
      }
    )

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.each(@input_document, '/handler/parameters/parameter') { |node|
      @parameters[node.attributes['name']] = node.text
    }
    puts("Parameters: #{@parameters.inspect}") if @debug_logging_enabled

    # If search by is User Name, determine if UPN suffix is present
    # Set the @search_by to the actual attribute name for the search filter
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
      raise "Unknown search by attribute: #{@parameters['search_by']}"
    end

    if @debug_logging_enabled
      puts("Searching attribute '#{@search_by}' for '#{@parameters['search_value']}'")
    end
  end

  # Searches for the user in the Active Directory server based on the search
  # parameters starting with a filter for organizationalPerson.
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
      # returned
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

      # locate the user account control attribute
      uac = user_entries[0].userAccountControl[0].to_i
      # determine the status of the flag for logging
      if @debug_logging_enabled
        mask = 1 << 16
        if mask & uac == 0
          puts "Password was previously set to expire"
        else
          puts "Password was already set to permanent"
        end
      end
      # regardless of the status, set the bit so 'password never expires'
      val = uac | 0x10000
      # set the attribute back which will enable the account
      @ldap.replace_attribute(user_entries[0].dn, :useraccountcontrol, val.to_s)
      # Raise an exception if there was a problem with the call
      unless @ldap.get_operation_result.code == 0
        raise @ldap.get_operation_result.message
      end
    else
      # authentication failed
      raise "Directory authentication failed - #{@ldap.get_operation_result}"
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