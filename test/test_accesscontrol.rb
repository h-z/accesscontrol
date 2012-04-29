require 'active_record'

require 'helper'
ActiveRecord::Migration.verbose = false
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

def setup_db
    ActiveRecord::Schema.define(:version => 1) do
        create_table :users do |t|
            t.column :name, :string
            t.column :created_at, :datetime      
            t.column :updated_at, :datetime
        end
        create_table :big_subjects do |t|
            t.column :name, :string
            t.column :created_at, :datetime      
            t.column :updated_at, :datetime
        end

        create_table :small_subjects do |t|
            t.column :name, :string
            t.column :created_at, :datetime      
            t.column :updated_at, :datetime
        end

        create_table :small_things do |t|
            t.column :name, :string
            t.column :small_subject_id, :integer
            t.column :created_at, :datetime      
            t.column :updated_at, :datetime
        end
 
        create_table :rules do |t|
            t.column :user_id, :integer
            t.column :subject_type, :string
            t.column :subject_id, :integer
            t.column :creator_id, :integer
            t.column :created_at, :datetime      
            t.column :updated_at, :datetime
        end
    end
end

class User < ActiveRecord::Base
    access_holder
end

class BigSubject < ActiveRecord::Base
    access_controlled
end

class SmallSubject < ActiveRecord::Base
    access_controlled
    has_many :small_things
end

class SmallThing <  ActiveRecord::Base
    belongs_to :small_subject
    access_controlled :proxy => :small_subject
end

class Rule < ActiveRecord::Base
  attr_accessible :creator_id, :subject_id, :subject_type, :user_id, :user, :subject, :creator
  #belongs_to :user
  belongs_to :subject, :polymorphic => true
  belongs_to :user, :foreign_key => :user_id
  belongs_to :creator, :class_name => User, :foreign_key => :creator_id

end


def create_instances
    ['Joe', 'Mary', 'John', 'Esmeralda'].each {|name| User.create(name: name) }
    ['Big', 'Bigger', 'Biggest', 'Big old big'].each {|big| BigSubject.create(name: big)}
    ['Small', 'Smaller', 'Smallest'].each {|small| SmallSubject.create(name: small)}
    subjects = SmallSubject.all
    ['ant', 'spider', 'bug', 'feature', 'termite', 'sand', 'atom'].each_with_index {|thing, index| SmallThing.create(name: thing, small_subject: subjects[index / 4 + 1])}
end

def teardown_db
    ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Base.connection.drop_table(table)
    end
end

class TestAccesscontrol < Test::Unit::TestCase
    context "Joe" do
        setup do
            setup_db
            create_instances
            @joe = User.find_by_name('Joe')
            @big = BigSubject.find_by_name('Big')
            @joe.grant(@joe, @big)

        end

        teardown do
            teardown_db
        end

        should "have access to Big" do
           assert_equal true, @joe.has_access?(@big)
        end

        should "have big in subjects" do
            assert_equal true, @joe.subjects.include?(@big)
        end
        
        should "have no access to Big after revoke" do
            @joe.revoke(@joe, @big)
            assert_equal false, @joe.has_access?(@big)
            assert_equal false, @joe.subjects.include?(@big)
            assert_equal false, @big.holders.include?(@joe)
        end

    end
end

class TestAccesscontrolProxy < Test::Unit::TestCase
    context "Joe" do
        setup do
            setup_db
            create_instances
            @joe = User.find_by_name('Joe')
            @ant = SmallThing.find_by_name('ant')
        end

        teardown do
            teardown_db
        end

        should "have access to Ant" do           
            assert_equal false, @joe.has_access?(@ant)
            @joe.grant(@joe, @ant)
            assert_equal true, @joe.has_access?(@ant)
        end

        should " have equal rules after unnecessary grant" do
            @joe.grant(@joe, @ant)
            before_rules = @joe.rules
            @joe.grant(@joe, @ant)
            after_rules = @joe.rules
            assert_equal before_rules, after_rules
        end
        
        should "have access to small thing through proxy" do
            small_subject = @ant.small_subject
            @joe.grant(@joe, small_subject)
            assert_equal true, @joe.has_access?(@ant)
        end

    end
end

