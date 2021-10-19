# Active Directory Group Members Retrieve
Retrieves a comma delimited list of group members.

For more information, see the Detailed Description section below.

## Parameters
[Error Handling] 
    How to handle error conditions in the handler: raise the error, or return error message.

[Group Name]
    The AD Group Name to search for

[Include Nested Groups]
    If members of nested groups are also desired, value should be set to true else set to
	false to only get the direct groups members

[User Attribute To Return]
    AD User attribute to return. Only 1 attribute allowed. Example: samaccountname

### Sample Configuration
Group Name::              	Kinetic-Test

Include Nested Groups::     false

User Attribute To Return::  samaccountname

## Results
Handler Error Message::     Error message if an error was encountered and Error Handling is set to "Error Message".

Group Member User List::    Comma separated list of group members (by user attribute)

## Detailed Description
This handler will use the server information and user credentials configured in the task info values to authenticate and connect to the specified Active Directory server (using LDAP) and search for the group on the search parameters provided.

## Important Notes
* This handler has been tested on Task 5.0.8 and should preform as expected on
all Task 5.x.x versions.
* The handler supports LDAPS by setting the tls info value to 'True'.
  * The method used to establish LDAPS is simple tls.  The method encrypts all communications with the LDAP server.
  * The handler completely establishes SSL/TLS encryption with the LDAP server before any LDAP-protocol data is exchanged. There is no plaintext negotiation and no special encryption-request controls are sent to the server.
  * The simple tls method intended for cases where you have an implicit level of trust in the authenticity of the LDAP server. No validation of the LDAP server's SSL certificate is performed. This means that the handler will not produce errors if the LDAP server's encryption certificate is not signed by a well-known Certification Authority.