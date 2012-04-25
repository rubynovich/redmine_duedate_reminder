require 'redmine'

Redmine::Plugin.register :redmine_duedate_reminder do
  name 'Duedate reminder'
  author 'Roman Shipiev'
  description 'E-mail notification of issues due date you are involved in (Assignee, Author, Watcher)'
  version '0.0.2'
  author_url 'http://roman.shipiev.me'
end

