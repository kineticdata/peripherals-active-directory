# Active Directory User Create
Creates an Active Directory user entry and uses the provided parameter values to
specify common user attributes.  This handler will fail if the user already
exists.

For more information, see the Detailed Description section below.

## Parameters
[Error Handling] 
    How to handle error conditions in the handler: raise the error, or return error message
    
[User Logon]
  The user's logon id.  This value should be specified as a User Principal Name
  (UPN) using the format 'username@domain.com'.  By convention, the User Logon
  is typically set to the same value as the user's email addresses.  In older
  Active Directory implementations, the domain may be omitted and the User Logon
  may be provided using the format 'username'.

[First Name]
  The first name of the user.

[Last Name]
  The last name of the user.

[Full Name]
  The full name of the user.  In most Active Directory implementations, this
  value must be unique.

[Description]
  The description of the user.  This value is displayed within the Active
  Directory user list and is often used to describe the role or purpose of a
  user account.

[Office]
  A string representing the location of the user's office.  This could be a
  building name, floor, room or cube number, or any combination of values.

[Telephone]
  The primary telephone number of the user.

[Email]
  The email address of the user.

[Title]
  The user's job title.

[Department]
  The primary department that the user is a member of.

[Company]
  The name of the company that the user is employed by.

[Activated]
  Indicates whether or not the the user's account should be activated upon
  creation.  Valid values are 'Yes' and 'No' (defaults to 'Yes').

## Sample Configuration
User Logon::   <%=@results['First Name']%>.<%=@results['Last Name']%>@domain.com

First Name::   <%=@results['First Name']%>

Last Name::    <%=@results['Last Name']%>

Full Name::    <%=@results['Full Name']%>

Description::  <%=@results['Employee Type']%>

Office::       <%=@results['Office Location']%>

Telephone::    <%=@results['Business phone']%>

Email::        <%=@results['Email Address']%>

Title::        <%=@results['Title']%>

Department::   <%=@results['Dept']%>

Company::      <%=@results['Company']%>

Activated::    Yes

## Results
Handler Error Message::     Error message if an error was encountered and 
                            Error Handling is set to "Error Message".

Distinguished Name::        The distinguished name of the user entry that was created.  
                            For example: CN=Daniel R Thompson,CN=Users,DC=kineticdata,DC=com

## Detailed Description
This handler will use the server information and user credentials configured in
the task info values to authenticate and connect to the specified Active
Directory server (using LDAP) and create a user entry.

In order to build up the Distinguished Name (a unique identifier for the active
directory user entry), the handler uses a template specified as a task info
value.

The following entry attributes are set once the user entry is created:
* Direct Mappings
  - givenname                     => First Name
  - sn                            => Last Name
  - displayname                   => Full Name
  - description                   => Description
  - physicaldeliveryofficename    => Office
  - telephonenumber               => Telephone
  - mail                          => Email
  - title                         => Title
  - department                    => Department
  - company                       => Company
* Computed Mappings
  - userprincipalname => Is set the the "User Logon" parameter if it was
                         provided using the User Principal Name format.  This
                         attribute is not set if the "User Logon" parameter was
                         provided without the "@domain" suffix.
  - samaccountname    => Is set to the username portion of the "User Logon"
                         parameter.
  - initials          => A concatenated string of the capitalized first letters
                         of each word in the "Full Name" parameter.
* Special Attributes
  - objectclass       => [top,person,organizationalPerson,user]

If the node parameter "Activated" is set to 'Yes', the user will be activated
immediately after the entry attributes have been set.

## Task Info Configuration
* *dn_format* - This value is used to specify the distinguished name of the
  Active Directory user entry to be created.  Anything within curly braces {}
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