# Active Directory User Retrieve
Retrieves a user based on Distinguished Name, Full Name, User Logon, or Email
Address.  This handler will fail if the user is not found, or if more than one
result is found.

For more information, see the Detailed Description section below.

## Parameters
[Error Handling] 
    How to handle error conditions in the handler: raise the error, or return error message

[Search By]
    'Dinstinguished Name', 'Full Name', 'User Logon', or 'Email Address'

[Search Value]
    The value of the Distinguished Name, Full Name, User Logon, or Email
    Address to search for

### Sample Configuration
Search By::                             User Logon

Search Value::                          <%=@answers['ReqFor Login ID']%>

## Results
Handler Error Message::     Error message if an error was encountered and 
                            Error Handling is set to "Error Message".

Distinguished Name::        The globally-unique text string for this user in
                            Active Directory

First Name::                The first name of the user

Last Name::                 The last name of the user

Full Name::                 The full name of the user

Manager DN::				        The DN of the user's manager

Initials::                  The initials for the user

Description::               User description field

Office::                    A string representing the location of the user's
                            office.

Telephone::                 The primary telephone number of the user

Email Address::             The email address of the user.

User Logon::                The User Logon name

User Principal Name::       The User Principal name

Account Enabled::           True or False, whether the account is enabled.

Title::                     The user's job title.

Department::                The primary department that the user is a member of

Company::                   The name of the company that the user is employed by


## Detailed Description
This handler will use the server information and user credentials configured in
the task info values to authenticate and connect to the specified Active
Directory server (using LDAP) and search for the user based on the
search parameters provided.  If User Logon is the 'search by' parameter, the
handler looks for a '@' symbol in the User Logon to determine how to search for
the User Logon name.  A '@' symbol indicates a search for the LDAP attribute
userPrincipalName (up to 100 characters) while the absence of the '@' symbol
will result in a search for the LDAP attribute sAMAccountName (pre-Windows 2000).

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