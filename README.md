### Chef Boundary Annotations Handler

This is a Chef handler for taking sucsessful changes and exceptions via Chef and create Boundary Annotations from them

Append the following to your Chef client configs, usually at `/etc/chef/client.rb`

    # Create a Boundary Annotation when a Chef run fails

    # cacert.pem needs to be in the same directory as chef-boundary-annotations-handler
    require 'chef-boundary-annotations-handler'
    # require '/path/to/chef-boundary-annotations-handler'

    # github account information for creating a gist of the exception
    github_user = "foobar"
    github_token = "asdfadsf"

    # boundary account information for creating the annotation
    boundary_orgid = "v9dnd9dm"
    boundary_apikey = "cs3odm93nd"

    boundary_annotations = BoundaryAnnotations.new(boundary_orgid, boundary_apikey, github_user, github_token)

    # enable it as a exception handler
    exception_handlers << boundary_annotations

    # enable it as a report handler (only creates an annotation for changes)
    report_handlers << boundary_annotations