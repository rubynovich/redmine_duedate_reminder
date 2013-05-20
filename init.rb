require 'redmine'

Redmine::Plugin.register :redmine_duedate_reminder do
  name 'Duedate reminder'
  author 'Roman Shipiev'
  description 'E-mail notification of issues due date you are involved in (Assignee, Author, Watcher)'
  version '0.0.5'
  url 'https://bitbucket.org/rubynovich/redmine_duedate_reminder'
  author_url 'http://roman.shipiev.me'
end

if Rails::VERSION::MAJOR < 3
  require 'dispatcher'
  object_to_prepare = Dispatcher
else
  object_to_prepare = Rails.configuration
end

object_to_prepare.to_prepare do
  [:issue, :mailer].each do |cl|
    require "duedate_reminder_#{cl}_patch"
  end

  [
    [Issue, DuedateReminderPlugin::IssuePatch],
    [Mailer, DuedateReminderPlugin::MailerPatch]
  ].each do |cl, patch|
    cl.send(:include, patch) unless cl.included_modules.include? patch
  end
end
