module Accesscontrol
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # @param [Hash] options
    def access_controlled(options = {})
      configuration = { :proxy => nil }
      configuration.update(options) if options.is_a?(Hash)

      define_method :accesscontrol_proxy do
        if configuration[:proxy].nil?
          self
        else
          if self.respond_to?(configuration[:proxy])
            self.send(configuration[:proxy]).accesscontrol_proxy
          else
            self
          end
        end
      end

      has_many :rules, :as => :subject

      include ControlledInstanceMethods
    end

    def access_holder
      include HolderInstanceMethods
    end
  end

  module ControlledInstanceMethods
    def holders
      accesscontrol_proxy.rules.collect {|rule| rule.user }.compact.uniq
    end

    # @param [User] user
    def add_user(user)
      owner.grant(user, accesscontrol_proxy)
    end

    # @param [User] user
    def remove_user(user)
      owner.revoke(user, accesscontrol_proxy)
    end

  end

  module HolderInstanceMethods
    def owner?
      true
    end

    def subjects
      rules.collect {|rule| rule.subject }.compact
    end

    # @param [ActiveRecord::Base] subject
    def has_access?(subject)
      return false unless subject.respond_to?(:accesscontrol_proxy)
      subjects.include? subject.accesscontrol_proxy
    end

    # @param [User] user
    # @param [ActiveRecord::Base] subject
    def grant(user, subject)
      return nil unless owner?
      return nil unless subject.respond_to?(:accesscontrol_proxy)
      unless user.has_access? subject
        user.rules << Rule.new({user: user, subject: subject.accesscontrol_proxy, creator: self})
      end
      user.rules
    end

    # @param [User] user
    # @param [ActiveRecord::Base] subject
    def revoke(user, subject)
      return nil unless owner?
      return nil unless subject.respond_to?(:accesscontrol_proxy)
      if user.has_access? subject
        user.rules.collect do |rule|
          rule if rule.subject == subject.accesscontrol_proxy
        end.compact.each do |rule|
          user.rules.delete rule
        end
      end
      user.rules
    end
  end
end

# ActiveRecord::Base.send :include, Accesscontrol
