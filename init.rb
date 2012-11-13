require 'redmine'

Redmine::Plugin.register :redmine_duedate_reminder do
  name 'Напоминалка о просроченных задачах'
  author 'Roman Shipiev'
  description 'Рассылает напоминания посредством E-Mail, что срок выполнения задачи уже близок. Рассылка производится как исполнителям, так и авторам с наблюдателями. Модуль реализован в виде rake-задачи'
  version '0.0.4'
  url 'https://github.com/rubynovich/redmine_duedate_reminder'
  author_url 'http://roman.shipiev.me'
end

