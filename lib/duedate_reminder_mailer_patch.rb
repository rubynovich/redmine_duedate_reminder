require_dependency 'mailer'

module DuedateReminderPlugin
  module MailerPatch
    def self.included(base)
      base.extend(ClassMethods)

      base.send(:include, InstanceMethods)

      base.class_eval do
      end
    end

    module ClassMethods
      def duedate_reminders_all(options={})
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
        return if over_due.blank?

        over_due = over_due.sort_by{|x| "#{x[0].mail}#{x[1]}" }
        previous_user = over_due[0][0]
        watched_tasks, auth_tasks, assigned_tasks, sent_issues = [], [], [], []

        over_due.each do |user, type, issues|
          sent_issues.each do |issue|
            issues -= [issue]
          end
          if previous_user != user
            assigned_tasks = assigned_tasks.sort_by(&:due_date).reverse if assigned_tasks.present?
            auth_tasks = auth_tasks.sort_by(&:due_date).reverse         if auth_tasks.present?
            watched_tasks = watched_tasks.sort_by(&:due_date).reverse   if watched_tasks.present?
            assigned_tasks.clear if notify_assignees.zero?
            auth_tasks.clear     if notify_authors.zero?
            watched_tasks.clear  if notify_watchers.zero?
            if (assigned_tasks | auth_tasks | watched_tasks).present? && previous_user.present?
              duedate_reminder_all(previous_user, assigned_tasks, auth_tasks, watched_tasks, days, mailcopy).deliver
            end
            watched_tasks.clear
            auth_tasks.clear
            assigned_tasks.clear
            sent_issues.clear
            previous_user = user
          end
          case type
            when "assignee" then assigned_tasks += issues
            when "author"   then auth_tasks += issues
            when "watcher"  then watched_tasks += issues
          end
          sent_issues += issues
        end

        assigned_tasks.clear if notify_assignees.zero?
        auth_tasks.clear     if notify_authors.zero?
        watched_tasks.clear  if notify_watchers.zero?
        if (assigned_tasks | auth_tasks | watched_tasks).present? && previous_user.present?
          duedate_reminder_all(previous_user, assigned_tasks, auth_tasks, watched_tasks, days, mailcopy).deliver
        end
      end
    end

    module InstanceMethods
      def duedate_reminder_all(user, assigned_issues, auth_issues, watched_issues, days, mailcopy)
        set_language_if_valid user.language
        day_tag = [l(:mail_duedate_reminder_all_day1),l(:mail_duedate_reminder_all_day2),l(:mail_duedate_reminder_all_day2),l(:mail_duedate_reminder_all_day2),l(:mail_duedate_reminder_all_day5)]
        issues_count = (assigned_issues | auth_issues | watched_issues).size
        subject = case issues_count
          when 1 then  l(:mail_subject_duedate_reminder_all1, :count => issues_count, :days => days, :day => day_tag[days>4 ? 4 : days-1])
          when 2..4 then l(:mail_subject_duedate_reminder_all2, :count => issues_count, :days => days, :day => day_tag[days>4 ? 4 : days-1])
          else l(:mail_subject_duedate_reminder_all5, :count => issues_count, :days => days, :day => day_tag[days>4 ? 4 : days-1])
        end
        @assigned_issues = assigned_issues.uniq
        @auth_issues = auth_issues.uniq
        @watched_issues = watched_issues.uniq
        @days = days
        @firstname = user.firstname
        @lastname = user.lastname
        @issues_url = url_for(:controller => 'issues', :action => 'index', :set_filter => 1, :assigned_to_id => user.id, :sort_key => 'due_date', :sort_order => 'asc')
        mail(:to => user.mail, :cc => mailcopy, :subject => subject) if user.mail.present? && (assigned_issues | auth_issues | watched_issues).size>0
      end
    end
  end
end
