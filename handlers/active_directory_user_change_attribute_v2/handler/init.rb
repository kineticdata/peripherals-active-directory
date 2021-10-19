# Add the dependencies file to require vendor libs
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ActiveDirectoryUserChangeAttributeV2
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
      get_ldap_config()
    )

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.each(@input_document, '/handler/parameters/parameter') { |node|
      @parameters[node.attributes['name']] = node.text
    }
    puts("Parameters: #{@parameters.inspect}") if @debug_logging_enabled

    @error_handling  = @parameters["error_handling"]
    @error_message = nil

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
      @error_message = "Unknown search by attribute: #{@parameters['search_by']}"
      raise "Unknown search by attribute: #{@parameters['search_by']}" if @error_handling == "Raise Error"
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
    begin

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
          @error_message = "Message: #{@ldap.get_operation_result.message}, Error Code: "\
						"#{@ldap.get_operation_result.code}"
          raise "Message: #{@ldap.get_operation_result.message}, Error Code: "\
            "#{@ldap.get_operation_result.code}" if @error_handling == "Raise Error"
        end

        # Raise exception if search did not return 1 entry
        if user_entries.length < 1
          @error_message = "User not found when searching by #{@search_by} " +
            "for: #{@parameters['search_value']}" if @error_message.nil?
          raise "User not found when searching by #{@search_by} for: "\
						"#{@parameters['search_value']}" if @error_handling == "Raise Error"
        elsif user_entries.length > 1
          @error_message = "Search matched more than one entry when searching by #{@search_by} " +
            "for: #{@parameters['search_value']}" if @error_message.nil?
          raise "Search matched more than one entry when searching by #{@search_by} for: "\
						"#{@parameters['search_value']}" if @error_handling == "Raise Error"
        end
        
        # set the attribute back which will enable the account
        @ldap.replace_attribute(user_entries[0].dn, @parameters['ldap_attribute'], @parameters['new_value'])
        # Raise an exception if there was a problem with the call
        unless @ldap.get_operation_result.code == 0
          @error_message = @ldap.get_operation_result.message
          raise @ldap.get_operation_result.message if @error_handling == "Raise Error"
        end
      else
        # authentication failed
        @error_message = "Directory authentication failed - #{@ldap.get_operation_result}" if @error_message.nil?
        raise "Directory authentication failed - #{@ldap.get_operation_result}" if @error_handling == "Raise Error"
      end
    rescue Exception => error
      @error_message = error.inspect if @error_message.nil?
      raise error if @error_handling == "Raise Error"
    end

    # Build, log, and return the results
    results = <<-RESULTS
    <results>
      <result name="Handler Error Message">#{escape(@error_message)}</result>
    </results>
    RESULTS
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

  def get_ldap_config()
    # Determine if TLS should be applied.
    is_tls = @info_values['tls'] == 'True'
  
    puts "TLS is #{is_tls ? 'enabled' : 'disabled'}, making connection on port #{@info_values['port']}" if @debug_logging_enabled
  
    # Initialize the Net::LDAP object with the credentials
    ldap_config = {
      :host => @info_values['host'],
      :port => @info_values['port'],
      :auth => {
        :method => :simple,
        :username => @info_values['username'],
        :password => @info_values['password']
      }
    }
    # Add encryption if using TLS
    ldap_config[:encryption] = { :method => :simple_tls } if is_tls
  
    # Return the ldap configuration
    ldap_config
  end
end