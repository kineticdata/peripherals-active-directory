Active Directory Group Members Retrieve
Retrieves a comma delimited list of group members.

For more information, see the Detailed Description section below.

=== Parameters
[Error Handling] 
    How to handle error conditions in the handler: raise the error, or return error message
[Group Name]
    The AD Group Name to search for
[Include Nested Groups]
    If members of nested groups are also desired, value should be set to true else set to
	false to only get the direct groups members
[User Attribute To Return]
    AD User attribute to return. Only 1 attribute allowed. Example: samaccountname

=== Sample Configuration
Group Name::              	Kinetic-Test
Include Nested Groups::     false
User Attribute To Return::  samaccountname

=== Results
Handler Error Message::     Error message if an error was encountered and 
                            Error Handling is set to "Error Message".
Group Member User List::    Comma separated list of group members (by user attribute)

=== Detailed Description
This handler will use the server information and user credentials configured in
the task info values to authenticate and connect to the specified Active
Directory server (using LDAP) and search for the group on the
search parameters provided.

=== Important Note
This handler has been tested on Task 4.0.6 and should preform as expected on
all Task 4.x.x versions.