# redMine - project management software
# Copyright (C) 2008  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

desc <<-END_DESC
Send reminders about issues due in the next days.

Available options:
  * days     => number of days to remind about (defaults to 5)
  * tracker  => id of tracker (defaults to all trackers)
  * project  => id or identifier of project (defaults to all projects)
  * assignees=> [0,1] include assigned issues (defaults to 1)
  * authors  => [0,1] include created issues (defaults to 0)
  * watchers => [0,1] include watched issues (defaults to 0)
  * cc       => send a copy of each message to this address (no copy per default)
Example:
  rake redmine:send_duedate_reminders_all days=7 RAILS_ENV="production"
END_DESC

namespace :redmine do
  task :send_duedate_reminders_all => :environment do
    options = {}
    options[:days] = ENV['days'].to_i if ENV['days']
    options[:project] = ENV['project'] if ENV['project']
    options[:tracker] = ENV['tracker'].to_i if ENV['tracker']
    options[:cc] = ENV['cc'] if ENV['cc']
    options[:watchers] = ENV['watchers'].to_i if ENV['watchers']
    options[:authors] = ENV['authors'].to_i if ENV['authors']
    options[:assignees] = ENV['assignees'].to_i if ENV['assignees']
    DuedateReminderMailer.duedate_reminders_all(options)
  end
end
