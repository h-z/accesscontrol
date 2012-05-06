module Accesscontrol
    def self.included(base)
        base.extend(ClassMethods)
    end

    module ClassMethods

        @@holder_class = Object
        @@controlled_classes = []
        # @param [Hash] options
        def access_controlled(options = {})
            @@controlled_classes << self
            configuration = { :proxy => nil }
            configuration.update(options) if options.is_a?(Hash)

            define_method :accesscontrol_proxy do
                if configuration[:proxy].nil?
                    self
                else
                    if self.respond_to?(configuration[:proxy])
                        unless self.send(configuration[:proxy]).nil?
                            self.send(configuration[:proxy]).accesscontrol_proxy
                        end
                    else
                        self
                    end
                end
            end
            has_many :rules, :as => :subject, :class_name => Accesscontrol::Rule
            include ControlledInstanceMethods
        end

        def access_holder
            @@holder_class = self
            has_many :rules, :class_name => Accesscontrol::Rule, :foreign_key => :holder_id
            has_many :created_rules, :class_name => Accesscontrol::Rule, :foreign_key => :creator_id
            Accesscontrol::Rule.module_eval do
                belongs_to :holder, :foreign_key => :holder_id, :class_name => Accesscontrol::ClassMethods.holder_class
                belongs_to :creator, :foreign_key => :creator_id, :class_name => Accesscontrol::ClassMethods.holder_class
            end

            include HolderInstanceMethods
        end

        def self.holder_class
            @@holder_class
        end
    end

    module ControlledInstanceMethods
        def holders
            accesscontrol_proxy.rules.collect {|rule| rule.holder }.compact.uniq
        end

        # @param [ActiveRecord::Base] user
        def add_user(user)
            owner.grant(user, accesscontrol_proxy)
        end

        # @param [ActiveRecord::Base] user
        def remove_user(user)
            owner.revoke(user, accesscontrol_proxy)
        end

    end

    module HolderInstanceMethods
        def owner?
            true
        end

        def subjects
            rules.collect {|rule| rule.subject.accesscontrol_proxy }.compact
        end

        # @param [ActiveRecord::Base] subject
        def has_access?(subject)
            return false unless subject.respond_to?(:accesscontrol_proxy)
            subjects.include? subject.accesscontrol_proxy
        end

        # @param [ActiveRecord::Base] user
        # @param [ActiveRecord::Base] subject
        def grant(user, subject)
            return nil unless owner?
            return nil unless subject.respond_to?(:accesscontrol_proxy)
            unless user.has_access? subject
                user.rules << Accesscontrol::Rule.new({holder: user, subject: subject.accesscontrol_proxy, creator: self})
            end
            user.rules
        end

        # @param [ActiveRecord::Base] user
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

    class Rule < ActiveRecord::Base
        attr_accessible :creator_id, :subject_id, :subject_type, :holder_id, :holder, :subject, :creator
        belongs_to :subject, :polymorphic => true
        # belongs_to :holder, :foreign_key => :holder_id
        # belongs_to :creator, :foreign_key => :creator_id, :class_name => Accesscontrol::ClassMethods.holder_class 
    end

end

ActiveRecord::Base.send :include, Accesscontrol
