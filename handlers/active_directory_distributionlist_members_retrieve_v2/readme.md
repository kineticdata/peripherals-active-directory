# Active Directory Distribution List Member Retrieve
Retrieves a comma delimited list of e-mail addresses (Belonging to People objects)
that belong to a specified Distribution Group.

For more information, see the Detailed Description section below.

## Parameters
[Error Handling] 
    How to handle error conditions in the handler: raise the error, or return error message

[Search By]
    'Distinguished Name', or 'Email Address'

[Search Value]
    The value of the Distinguished Name, or Email
    Address to search for

### Sample Configuration
Search By::                             Email Address

Search Value::                          distributionlistname@acmecompany.com

## Results
Handler Error Message::     Error message if an error was encountered and 
                            Error Handling is set to "Error Message".

Email Addresses::           The email addresses of all users in the group.

## Detailed Description
This handler will use the server information and user credentials configured in
the task info values to authenticate and connect to the specified Active
Directory server (using LDAP) and search for the distribution group on the
search parameters provided.  If Email Address is the 'search by' parameter, the
handler looks for a '@' symbol in the User Logon to determine how to search for
the User Logon name.  A '@' symbol indicates a search for the LDAP attribute
userPrincipalName (up to 100 characters) while the absence of the '@' symbol
will result in a search for the LDAP attribute sAMAccountName (pre-Windows 2000).

* If 'Distinguished Name' is selected, the 'distinguishedName' attribute will be
  used directly to retrieve the User objects that are a member of the provided group.
* If 'Email Address' is selected, the Distinguished Name of the group will first be
  searched for by the mail address.

## Important Notes
* The handler supports LDAPS by setting the tls info value to 'True'.
  * The method used to establish LDAPS is simple tls.  The method encrypts all communications with the LDAP server.
  * The handler completely establishes SSL/TLS encryption with the LDAP server before any LDAP-protocol data is exchanged. There is no plaintext negotiation and no special encryption-request controls are sent to the server.
  * The simple tls method intended for cases where you have an implicit level of trust in the authenticity of the LDAP server. No validation of the LDAP server's SSL certificate is performed. This means that the handler will not produce errors if the LDAP server's encryption certificate is not signed by a well-known Certification Authority.