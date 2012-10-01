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
require File.expand_path(File.dirname(__FILE__) + "/../../../../../config/environment")
require "mailer"
#require "actionmailer"

Issue.class_eval do
  named_scope :assigned, :conditions => "#{Issue.table_name}.assigned_to_id IS NOT NULL"
  
  named_scope :not_closed, {:conditions => "#{IssueStatus.table_name}.id != 3", :include => :status}
  
  named_scope :active_project, {:conditions => "#{Project.table_name}.status = #{Project::STATUS_ACTIVE}", :include => :project}
  
  named_scope :from_project, lambda{ |project| 
    {:conditions => "#{Issue.table_name}.project_id = #{project.id}"} if project
  }
  
  named_scope :from_tracker, lambda{ |tracker|
    {:conditions => "#{Issue.table_name}.tracker_id = #{tracker.id}"} if tracker
  }
  
  named_scope :not_completed, {:conditions => "#{Issue.table_name}.done_ratio < 100"}
  
  named_scope :must_be_finished, lambda{ |days|
    {:conditions => ["#{IssueStatus.table_name}.is_closed = ? AND #{Issue.table_name}.due_date <= ?", false, days.day.from_now.to_date], :include => :status}
  }  
end

class Duedate_Reminder_all < Mailer
  def duedate_reminder_all(user, assigned_issues, auth_issues, watched_issues, days, mailcopy)
    set_language_if_valid user.language
    recipients user.mail
    cc mailcopy if mailcopy
    day_tag=[l(:mail_duedate_reminder_all_day1),l(:mail_duedate_reminder_all_day2),l(:mail_duedate_reminder_all_day2),l(:mail_duedate_reminder_all_day2),l(:mail_duedate_reminder_all_day5)]
    case (assigned_issues+auth_issues+watched_issues).uniq.size
      when 1 then subject l(:mail_subject_duedate_reminder_all1, :count => ((assigned_issues+auth_issues+watched_issues).uniq.size), :days => days, :day=>day_tag[days>4 ? 4 : days-1])
      when 2..4 then subject l(:mail_subject_duedate_reminder_all2, :count => ((assigned_issues+auth_issues+watched_issues).uniq.size), :days => days, :day=>day_tag[days>4 ? 4 : days-1])
      else subject l(:mail_subject_duedate_reminder_all5, :count => ((assigned_issues+auth_issues+watched_issues).uniq.size), :days => days, :day=>day_tag[days>4 ? 4 : days-1])
    end
    body :assigned_issues => assigned_issues.uniq,
         :auth_issues => auth_issues.uniq,
         :watched_issues => watched_issues.uniq,
         :days => days,
         :firstname => user.firstname,
         :lastname => user.lastname,
         :issues_url => url_for(:controller => 'issues', :action => 'index', :set_filter => 1, :assigned_to_id => user.id, :sort_key => 'due_date', :sort_order => 'asc')
    render_multipart('duedate_reminder_all', body) if (assigned_issues+auth_issues+watched_issues).uniq.size>0
  end
  def self.duedate_reminders_all(options={})
    days = options[:days] || 5
    project = options[:project] ? Project.find(options[:project]) : nil
    tracker = options[:tracker] ? Tracker.find(options[:tracker]) : nil
    notify_assignees = options[:assignees] ? options[:assignees] : 1
    notify_watchers = options[:watchers] ? options[:watchers] : 0
    notify_authors = options[:authors] ? options[:authors] : 0 
    mailcopy = options[:cc] ? options[:cc] : nil

    over_due = Array.new
    issues_by_assignee = Issue.
      assigned.
      not_closed.
      active_project.
      from_project(project).
      from_tracker(tracker).
      not_completed.
      must_be_finished(days).
      find(:all, :include => [:assigned_to, :tracker]).
      group_by(&:assigned_to)
    
    issues_by_assignee.each do |assignee, issues|
      found=0
      over_due.each do |person|
        if person[0].mail == assignee.mail && person[1]=="assignee" then
          person << issues
          found=1
        end
      end
      if found==0 then
        over_due<<[assignee, "assignee", issues]
      end
    end

    issues_by = Issue.
      active_project.
      from_project(project).
      from_tracker(tracker).
      must_be_finished(days).
      find(:all, :include => [:author, :tracker, :watchers])

    issues_by.group_by(&:author).each do |author, issues|
      found=0
      over_due.each do |person|
        if person[0].mail == author.mail && person[1]=="author" then
          person << issues
          found=1
        end
      end
      if found==0 then
        over_due<<[author, "author", issues]
      end
    end
    issues_by.group_by(&:watchers).each do |watchers, issues|
      found_watchers = Array.new
      over_due.each do |person|
        watchers.each do |watcher|
          if person[0].mail == watcher.user.mail && person[1]=="watcher" then
            found_watchers << watcher
            person[2] += issues
          end
        end
      end
      watchers = watchers - found_watchers
      watchers.each do |watcher|
        over_due<<[watcher.user, "watcher", issues]
      end
    end
    over_due.sort_by!{|x| "#{x[0].mail}#{x[1]}" }
    previous_user = over_due[0][0]
    watched_tasks = Array.new
    auth_tasks = Array.new
    assigned_tasks = Array.new
    sent_issues = Array.new
    over_due.each do |user, type, issues|
      sent_issues.each do |issue|
        issues-=[issue]
      end
      if previous_user == user then
        if type == "assignee" then
          assigned_tasks += issues
          sent_issues += issues
        elsif type == "author" then
          auth_tasks += issues
          sent_issues += issues
        elsif type == "watcher" then
          watched_tasks += issues
          sent_issues += issues
        end        
      else
        if assigned_tasks.length > 0 then
          assigned_tasks.sort! {|a,b| b.due_date <=> a.due_date }
        end
        if auth_tasks.length > 0 then
          auth_tasks.sort! {|a,b| b.due_date <=> a.due_date }
        end
        if watched_tasks.length > 0 then
          watched_tasks.sort! {|a,b| b.due_date <=> a.due_date }
        end
        assigned_tasks.clear if notify_assignees == 0
        auth_tasks.clear if notify_authors == 0
        watched_tasks.clear if notify_watchers == 0
        if ((assigned_tasks+auth_tasks+watched_tasks).uniq.size > 0) then
          deliver_duedate_reminder_all(previous_user, assigned_tasks, auth_tasks, watched_tasks, days, mailcopy) unless previous_user.nil?
        end
        watched_tasks.clear
        auth_tasks.clear
        assigned_tasks.clear
        sent_issues.clear
        previous_user=user
        if type == "assignee" then
          assigned_tasks += issues
          sent_issues += issues
        elsif type == "author" then
          auth_tasks += issues
          sent_issues += issues
        elsif type == "watcher" then
          watched_tasks += issues
          sent_issues += issues
        end
      end
    end
    assigned_tasks.clear if notify_assignees == 0
    auth_tasks.clear if notify_authors == 0
    watched_tasks.clear if notify_watchers == 0
    if ((assigned_tasks+auth_tasks+watched_tasks).uniq.size > 0) then
      deliver_duedate_reminder_all(previous_user, assigned_tasks, auth_tasks, watched_tasks, days, mailcopy) unless previous_user.nil?
    end
  end
end

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
    Duedate_Reminder_all.duedate_reminders_all(options)
  end
end

