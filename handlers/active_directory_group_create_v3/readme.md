# Active Directory Group Create
Creates an Active Directory group entry and uses the provided parameter values to specify common attributes.  This handler will fail if the group already exists.

For more information, see the Detailed Description section below.

## Parameters
[Error Handling] 
    How to handle error conditions in the handler: raise the error, or return error message

[Group Name]
  The name of the group to be created

[Description]
  The description of this group

[Email Address]
  The Email Address for this group.  Active Directory can be configured so that all members of a group are notified when the group receives an Email

[Group Scope]
  Security groups or distribution groups are characterized by a scope that identifies how they are applied in the domain tree or forest.
  There are three group scopes: universal, global, and domain local.

[Group Type]
  There are two group types, security and distribution.  Security groups allow you to manage user and computer access to shared resources.  Distribution groups are intended to be used solely as email distribution lists.

[Notes]
  Additional information about the group

#### Sample Configuration
Group Name::        <%=@results['New Group Name']%>

Description::       Allows access to the accounting resources

Email Address::     Accounting@company.com

Group Scope::       Global

Group Type::        Security

Notes::             <%=@results['Notes']%>

### Results
Handler Error Message::     Error message if an error was encountered and Error Handling is set to "Error Message".

Distinguished Name::        CN=Accounting,CN=Users,DC=kineticdata,DC=com

## Detailed Description
This handler will use the server information and user credentials configured in the task info values to authenticate and connect to the specified Active Directory server (using LDAP) and create a group entry.

In order to build up the Distinguished Name (a unique identifier for the active directory user entry), the handler uses a template specified as a task info value.

The following entry attributes are set once the user entry is created:
* Direct Mappings
  - name              => Group Name
  - mail              => Email Address
  - description       => Description
  - info              => Notes
* Computed Mappings
  - grouptype         => Numerical representation of the group scope and type.
* Special Attributes
  - objectclass       => [top,group]

## Task Info Configuration
* *dn_format* - This value is used to specify the distinguished name of the
  Active Directory group entry to be created.  Anything within curly braces {}
  will be replaced with the value of the entry attribute or task info value
  associated with that key. For example, the default format is
  'CN={displayname},CN=Users,{base}'.  In this case {displayname} is replaced
  with the displayname attribute value and {base} is replaced with the value of
  the 'base' task info value.  A full list of available entry attributes is
  available above.  If you use organizational units they can be substituted into
  the distinguished name in this manner.

## Important Notes
* This handler has been tested on Task 5.0.8 and should preform as expected on
all Task 5.x.x versions.
* The handler supports LDAPS by setting the tls info value to 'True'.
  * The method used to establish LDAPS is simple tls.  The method encrypts all communications with the LDAP server.
  * The handler completely establishes SSL/TLS encryption with the LDAP server before any LDAP-protocol data is exchanged. There is no plaintext negotiation and no special encryption-request controls are sent to the server.
  * The simple tls method intended for cases where you have an implicit level of trust in the authenticity of the LDAP server. No validation of the LDAP server's SSL certificate is performed. This means that the handler will not produce errors if the LDAP server's encryption certificate is not signed by a well-known Certification Authority.