require_dependency 'issue'

module DuedateReminderPlugin
  module IssuePatch
    def self.included(base)
      base.extend(ClassMethods)

      base.send(:include, InstanceMethods)

      base.class_eval do
        if Rails::VERSION::MAJOR < 3
          named_scope :assigned, :conditions => "#{Issue.table_name}.assigned_to_id IS NOT NULL"

          named_scope :not_closed, {:conditions => "#{IssueStatus.table_name}.id != 3", :include => :status}

          named_scope :active_project, {:conditions => "#{Project.table_name}.status = #{Project::STATUS_ACTIVE}", :include => :project}

          named_scope :from_project, lambda{ |project|
            {:conditions => "#{Issue.table_name}.project_id = #{project.id}"} if project.present?
          }

          named_scope :from_tracker, lambda{ |tracker|
            {:conditions => "#{Issue.table_name}.tracker_id = #{tracker.id}"} if tracker.present?
          }

          named_scope :not_completed, {:conditions => "#{Issue.table_name}.done_ratio < 100"}

          named_scope :must_be_finished, lambda{ |days|
            {:conditions => ["#{IssueStatus.table_name}.is_closed = ? AND #{Issue.table_name}.due_date <= ?", false, days.day.from_now.to_date], :include => :status}
          }
        else
          scope :assigned, where("#{Issue.table_name}.assigned_to_id IS NOT NULL")

          scope :not_closed, {:conditions => "#{IssueStatus.table_name}.id != 3", :include => :status}

          scope :active_project, {:conditions => "#{Project.table_name}.status = #{Project::STATUS_ACTIVE}", :include => :project}

          scope :from_project, lambda{ |project|
            {:conditions => "#{Issue.table_name}.project_id = #{project.id}"} if project.present?
          }

          scope :from_tracker, lambda{ |tracker|
            {:conditions => "#{Issue.table_name}.tracker_id = #{tracker.id}"} if tracker.present?
          }

          scope :not_completed, where("#{Issue.table_name}.done_ratio < 100")

          scope :must_be_finished, lambda{ |days|
            {:conditions => ["#{IssueStatus.table_name}.is_closed = ? AND #{Issue.table_name}.due_date <= ?", false, days.day.from_now.to_date], :include => :status}
          }
        end
      end
    end

    module ClassMethods
    end

    module InstanceMethods

    end
  end
end
