# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class ActiveDirectoryUserCreateV2
  # Prepare for execution by building Hash objects for necessary data and
  # configuration values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @ldap - A Net::LDAP object that controls communication with the Active
  #   Directory server.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @attributes - A Hash of active directory entry attributes to be set for
  #   the user that is being created.
  # * @info_values - A Hash of task definition info item names to values.
  # * @dn - A String representing the distinguished name of the user entry that
  #   is being created.
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
      puts("Debug Logging Enabled...") 
      puts("Connecting to #{@info_values['host']}:#{@info_values['port']} as #{@info_values['username']}.")
      puts("Using #{@info_values['base']} for the base of the directory tree.")
      puts("Using #{@info_values['dn_format']} for the 'User' distinguished name template.")
    end

    @ldap = Net::LDAP.new(
      get_ldap_config()
    )

    # Store the parameters specified in the node.xml as a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.each(@input_document, '/handler/parameters/parameter') { |node|
      @parameters[node.attributes['name']] = node.text
    }
    puts("Parameters: #{@parameters.inspect}") if @debug_logging_enabled

    @error_handling  = @parameters["error_handling"]
    @error_message = nil
    
    # Store the user attributes specified in the node.xml as a hash attribute named @attributes.
    @attributes = {}
    REXML::XPath.each(@input_document, '/handler/attributes/attribute') { |node|
      @attributes[node.attributes['name']] = node.text
    }

    # Set additional user attributes based on the specified user_logon
    @attributes['userPrincipalName'] = @parameters['user_logon'] if @parameters['user_logon'].include? "@"
    @attributes['sAMAccountName'] = @parameters['user_logon'].split("@").first

    # Set the active directory entry object class based on the configuration in
    # the node.xml file.  The objectclass attribute needs to be mapped to an
    # array of object class names.
    object_classes_string = REXML::XPath.first(@input_document,
      "/handler/configurations/configuration[@name='objectclass']").text
    @attributes['objectclass'] = object_classes_string.split(",")

    # Set the initials attribute based on the full name
    # @attributes['initials'] = get_initials(@attributes['displayname']).to_s

    # Display all of the built attributes if debug logging is enabled
    puts("Attributes: #{@attributes.inspect}") if @debug_logging_enabled

    # Build the distinguished name for this user based on the info format.  The
    # dn format template allows variables from @attributes (entry attributes) or
    # @info_values (task info values) to be used.
    @dn = insert_values(@info_values['dn_format'], @attributes.merge(@info_values))
    @attributes.delete_if {|k,v| v.nil?}
    puts("Set distinguished name to: #{@dn}") if @debug_logging_enabled
  end

  # Connects to the Active Directory server and creates a user with the
  # distinguished name and parameters provided.
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
        # Create an entry for the specified distinguished name and add the
        # specified attributes.  This will throw an error if an entry associated
        # to the distinguished name already exists.
        @ldap.add( :dn => @dn, :attributes => @attributes )

        # Raise an exception if there was a problem with the call
        unless @ldap.get_operation_result.code == 0
          @error_message = "Message: #{@ldap.get_operation_result.message}, Error Code: "\
						"#{@ldap.get_operation_result.code}"
          raise "Message: #{@ldap.get_operation_result.message}, Error Code: "\
            "#{@ldap.get_operation_result.code}" if @error_handling == "Raise Error"
        end

        # Enable the account if the "Activated" parameter is set to "Yes"
        if @parameters['activated'] == "Yes"
          # The useraccountcontrol attribute is a special attribute that takes
          # a numerical representation of the control actions to execute.  The
          # value of 544 indicates that the user is activated (as a normal
          # account).
          @ldap.replace_attribute @dn, :useraccountcontrol, '544'
          # Raise exception if there was a problem with the call
          unless @ldap.get_operation_result.code == 0
            @error_message = "There was a problem activating the user for #{@dn} :: "\
						  "#{@ldap.get_operation_result.message}"
            raise "There was a problem activating the user for #{@dn} :: "\
						  "#{@ldap.get_operation_result.message}" if @error_handling == "Raise Error"
          end
        end
      else
        # authentication failed
        @error_message = "Directory authentication failed - #{@ldap.get_operation_result}"
        raise "Directory authentication failed - #{@ldap.get_operation_result}" if @error_handling == "Raise Error"
      end
    rescue Exception => error
      @error_message = error.inspect if @error_message.nil?
      raise error if @error_handling == "Raise Error"
    end

    # Return the results if we got this far (just the distinguished name)
    results = <<-RESULTS
    <results>
      <result name="Handler Error Message">#{escape(@error_message)}</result>
      <result name="Distinguished Name">#{@dn}</result>
    </results>
    RESULTS
    puts("Results: \n#{results}") if @debug_logging_enabled
	  return results
  end

  ##############################################################################
  # Active Directory User Create handler utility functions
  ##############################################################################

  # Returns an Array of the capitalized first letters of each word in the passed
  # parameter.
  #
  # Example:
  #   get_initials("John D. Doe")
  #     => "JDD"
  #
  # ==== Parameters
  # * displayname (String) - The LDAP attribute displayname which should be
  #   previously set from the Full Name paramater of the handler.
  #
  # ==== Returns
  # An array which is the capitalized first letters of each word (even if it's
  # only one character) in the displayname.
  def get_initials(displayname)
    displayname.split.map! { |word| word[0,1].capitalize }
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

  # Builds a String by replacing variables (specified by wrapping the variable
  # name between the '{' and '}' characters) within a template string with their
  # values. Variable names and values are passed as a Hash parameter.
  #
  # For template strings that require the use of the '{' character constant, it
  # can be escaped by prefixing the character with a backslash ('\' character).
  # Note, it is important to remember that the backslash character itself must
  # be escaped if it is being specified directly in Ruby code. For example:
  # template1 = 'Template \{1}'
  # and
  # template2 = "Template \\{2}"
  #
  # ==== Examples
  # The following examples illustrate sample uses of this method:
  # @template_variables = {'First Name' => 'John', 'Last Name' => 'Doe'}
  # puts insert_values('{First Name} {Last Name}', @template_variables)
  # => "John Doe"
  # puts insert_values('{{First Name}}', @template_variables)
  # => "{John}"
  # puts insert_values('\{First Name}: {First Name}', @template_variables)
  # => "{First Name}: John
  #
  # ==== Parameters
  # * template_string (String) - A String to be used as the "template" for the
  # result. Variables are specified by wrapping the variable name between the
  # '{' and '}' characters.
  # * template_variables (Hash) - A Hash of template variable names (Strings) to
  # template valiable values (Strings).
  #
  # ==== Returns
  # A String built by replacing the template_string's variables with the values
  # specified in the template_variables hash.
  def insert_values(template_string, template_variables)
    # Regular Expression Explanation /(\\{)|{(?!{)(.*?)}/:
    # (\\{) => Matches any "escaped" left brace (a left brace
    # immediately to the right of the backslash character).
    # If this expression is matched, the String '\{' is
    # stored in the first "group" (referenced with $1).
    # | => Indicates a logical "or," meaning that the regular
    # expression will match either the previous "escaped left
    # brace" expression or the proceeding "variable name"
    # expression.
    # {(?!{)(.*?)} => Matches any substring that starts with a left brace
    # that is not followed by another left brace (the
    # expression '(?!{)' is a negative lookahead expression
    # that ensures the match is using only the innermost
    # brackets), has any number non right brace characters
    # (representing the variable name), and ends with a right
    # brace. If this expression is matched, the substring
    # encased in the brackets is stored in the second "group"
    # (referenced with $2).

    # Replace all instances of the regular expression with the block result
    template_string.gsub(/(\\{)|{(?!{)(.*?)}/) do
      # Build the block result. If we are matching an escaped left brace,
      # return a single left brace. If we are matching a template variable (a
      # string surrounded by braces that represents a key in the
      # template_variables hash), return the variable value associated to the
      # name matching the string between the innermost left and right braces.
      $1 == "\\{" ? "{" : template_variables[$2]
    end
  end

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