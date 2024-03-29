# Add the dependencies file to require vendor libs
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ActiveDirectoryGroupMembersRetrieveV1

  # Load the LDAP bind information, build Hash objects for necessary values,
  # and validate the present state.  This method sets the following instance
  # variables:
  # * @input_document - A REXML::Document object that represents the input XML.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @info_values - A Hash of task definition info item names to values.
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

  end
  
  # Searches for the users in a group (including subgroups) in the Active Directory
  # server based on the search value parameter.  
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
      
        dl_ldap_dn = @parameters['search_value']
        dl_ldap_dn = getGroupDN()
          puts "Found DN for Group: #{dl_ldap_dn}" if @debug_logging_enabled
                
        if @parameters['include_nested_groups'] == "true"
		  puts "Including Nested Group Members for Group: #{dl_ldap_dn}" if @debug_logging_enabled
		  filter = Net::LDAP::Filter.construct("(&(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:=#{dl_ldap_dn}))")
		else
		  puts "Not Including Nested Group Members for Group: #{dl_ldap_dn}" if @debug_logging_enabled
		  filter = Net::LDAP::Filter.construct("(&(objectClass=user)(memberOf=#{dl_ldap_dn}))")
		end
        
        # Search operation - return result is set to true so that an array is returned
        user_entries = @ldap.search(
          :base => @info_values['base'],
          :filter => filter,
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
          @error_message = "User not found when searching by #{@search_by} "\
            "for: #{@parameters['search_value']}" if @error_message.nil?
          raise "User not found when searching by #{@search_by} for: "\
            "#{@parameters['search_value']}" if @error_handling == "Raise Error"
        else
      
          group_members_user_list = ""
          
          user_entries.each do |user_entry|
        
          # Build a user entry hash (this is easier to work with than the
          # Net::LDAP:Entry directly since we referencing attributes that are not
          # set will return nil instead of raising an exception.
          user_entry_hash = hashify_entry(user_entry)
          
          puts user_entry_hash.inspect if @debug_logging_enabled
          
          if !user_entry_hash[@parameters['user_attribute']].nil?
            group_members_user_list << user_entry_hash[@parameters['user_attribute']][0] + ","
          else
            puts "No #{@parameters['user_attribute']} attribute found for #{user_entry['dn'][0]}" if @debug_logging_enabled
          end
        end
      end
        group_members_user_list = group_members_user_list[0..-2]

      else
        # authentication failed
        @error_message = "Directory authentication failed - #{@ldap.get_operation_result}" if @error_message.nil?
        raise "Directory authentication failed - #{@ldap.get_operation_result}" if @error_handling == "Raise Error"
      end
    rescue Exception => error
      @error_message = error.inspect if @error_message.nil?
      raise error if @error_handling == "Raise Error"
    end

    # Return the results
    results = <<-RESULTS
    <results>
      <result name="Handler Error Message">#{escape(@error_message)}</result>
      <result name="Group Member User List">#{escape(group_members_user_list)}</result>
    </results>
    RESULTS
    puts("Results: \n#{results}") if @debug_logging_enabled
	  return results
  end

  ##############################################################################
  # Handler Helpers
  ##############################################################################

  # Returns a Hash of entry attribute name Strings to value Arrays.  When
  # interacting with Net::LDAP, all attribute values are returned as arrays.
  # If the attribute has a single value, it can typically be passed directly
  # into the escape function.  If there are multiple values, the result string
  # may be in an unexpected format (concatenating values rather than separating
  # them in some way).  For example, the Array ["1", "2", "3"] is escaped to the
  # String "123" rather than "1,2,3".
  #
  # ==== Parameters
  # * customer_survey_instance_id (String) - The 'instanceId' of the KS_SRV_CustomerSurvey_base
  #   record related to this submission.
  def hashify_entry(entry)
    # Raise an exception if we were passed an invalid entry
    raise "Unable to hashify a nil value." if entry.nil?
    # Initialize the hash
    hash = {}
    # For each of the entry attributes
    entry.each_attribute do |name, value|
      # Add the attribute name and value
      hash.merge!(name.to_s => value)
    end
    hash
  end
  
  def getGroupDN()
  
    filter = Net::LDAP::Filter.construct("(&(objectClass=group)(CN=#{@parameters['search_value']}))")
    
    # Search operation - return result is set to true so that an array is returned
    dl_entries = @ldap.search(
      :base => @info_values['base'],
      :filter => filter,
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
    if dl_entries.length < 1
      @error_message = "Group not found when searching for: "\
        "#{@parameters['search_value']}"
      raise "Group not found when searching for: "\
				"#{@parameters['search_value']}" if @error_handling == "Raise Error"
    elsif dl_entries.length > 1
      @error_message = "More than one Group was found when searching for: "\
				"#{@parameters['search_value']}"
      raise "More than one Group was found when searching for: "\
				"#{@parameters['search_value']}" if @error_handling == "Raise Error"
    end
    
    dl_entries[0]['dn'].first
    
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