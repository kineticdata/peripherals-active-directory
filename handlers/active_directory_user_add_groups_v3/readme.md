# Active Directory User Add Groups
Finds a user in active directory by Distinguished Name, Full Name,
Email Address, or User Logon and adds the user as a member to one or more
groups.

This handler will raise an Exception if the specified User or any of the
specified Groups are not found in the Active Directory system.


For more information, see the Detailed Description section below.

## Parameters
[Error Handling] 
    How to handle error conditions in the handler: raise the error, or return error message.

[Search By]
    'Distinguished Name', 'Full Name', 'User Name', or 'Email Address'

[Search Value]
    The value of the Distinguished Name, Full Name, User Logon, or Email
    Address that will be used to search for the desired user.

[Groups]
    The common name(s) of the group(s) to add.  More than one group can be
    specified by separating each group with a comma.

### Sample Configuration
Search By::                     User Name

Search Value::                  <%=@answers['ReqFor Login ID']%>

Groups::                        <%=@answers['Groups']%>

## Results
Handler Error Message::     Error message if an error was encountered and 
                            Error Handling is set to "Error Message".

## Detailed Description
This handler will use the server information and user credentials configured in
the task info values to authenticate and connect to the specified Active
Directory server (using LDAP) and search for the user based on the search
parameters provided.  If a matching user is found, it will be added as a member
to each group specified in the groups parameter will be added to the user.

* If 'Distinguished Name' is selected, the 'distinguishedName' attribute will be
  used directly to retrieve the User entry.
* If 'Full Name' is selected, the 'cn' attribute will be used to retrieve the
  User entry.
* If 'User Name' is selected, the 'userprincipalname' value will be used if the
  "Search Value" parameter includes an '@' sign (IE john.doe@domain.com) and the
  'samaccountname' will be used if it does not (IE john.doe).
* If 'Email Address' is selected, the 'mail' attribute will be used to retrieve
  the User entry.

This handler will raise an Exception if the specified User or any of the
specified Groups are not found in the Active Directory system.

## Important Notes
* This handler has been tested on Task 5.0.8 and should preform as expected on
all Task 5.x.x versions.
* The handler supports LDAPS by setting the tls info value to 'True'.
  * The method used to establish LDAPS is simple tls.  The method encrypts all communications with the LDAP server.
  * The handler completely establishes SSL/TLS encryption with the LDAP server before any LDAP-protocol data is exchanged. There is no plaintext negotiation and no special encryption-request controls are sent to the server.
  * The simple tls method intended for cases where you have an implicit level of trust in the authenticity of the LDAP server. No validation of the LDAP server's SSL certificate is performed. This means that the handler will not produce errors if the LDAP server's encryption certificate is not signed by a well-known Certification Authority.