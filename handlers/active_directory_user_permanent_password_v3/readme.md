# Active Directory User Permanent Password
Retrieves a user based on Distinguished Name, Full Name, User Logon, or Email
Address and sets the password so it never expires.  This handler will fail if
the user is not found, or if more than one result is found.

For more information, see the Detailed Description section below.

## Parameters
[Error Handling] 
    How to handle error conditions in the handler: raise the error, or return error message.

[Search By]
    'Distinguished Name', 'Full Name', 'User Logon', or 'Email Address'

[Search Value]
    The value of the Distinguished Name, Full Name, User Logon, or Email
    Address to search for

### Sample Configuration
Search By::                             User Logon

Search Value::                          <%=@answers['ReqFor Login ID']%>

## Results
Handler Error Message::     Error message if an error was encountered and Error Handling is set to "Error Message".
                            
## Detailed Description
This handler will use the server information and user credentials configured in
the task info values to authenticate and connect to the specified Active
Directory server (using LDAP) and search for the user based on the
search parameters provided.  If User Logon is the 'search by' parameter, the
handler looks for a '@' symbol in the User Logon to determine how to search for
the User Logon name.  A '@' symbol indicates a search for the LDAP attribute
userPrincipalName (up to 100 characters) while the absence of the '@' symbol
will result in a search for the LDAP attribute sAMAccountName(pre-Windows 2000).
Finally, the flag is set so the password never expires.

* If 'Distinguished Name' is selected, the 'distinguishedName' attribute will be
  used directly to retrieve the User entry.
* If 'Full Name' is selected, the 'cn' attribute will be used to retrieve the
  User entry.
* If 'User Name' is selected, the 'userprincipalname' value will be used if the
  "Search Value" parameter includes an '@' sign (IE john.doe@domain.com) and the
  'samaccountname' will be used if it does not (IE john.doe).
* If 'Email Address' is selected, the 'mail' attribute will be used to retrieve
  the User entry.

This handler will fail if the user is not found, or if more than one
result is found.

## Important Notes
* This handler has been tested on Task 5.0.8 and should preform as expected on
all Task 5.x.x versions.
* The handler supports LDAPS by setting the tls info value to 'True'.
  * The method used to establish LDAPS is simple tls.  The method encrypts all communications with the LDAP server.
  * The handler completely establishes SSL/TLS encryption with the LDAP server before any LDAP-protocol data is exchanged. There is no plaintext negotiation and no special encryption-request controls are sent to the server.
  * The simple tls method intended for cases where you have an implicit level of trust in the authenticity of the LDAP server. No validation of the LDAP server's SSL certificate is performed. This means that the handler will not produce errors if the LDAP server's encryption certificate is not signed by a well-known Certification Authority.