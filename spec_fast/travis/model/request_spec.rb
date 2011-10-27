require 'spec_helper'

class Request
  attr_accessor :state
  def save!; end
  def configure(data); end
  def commit; @commit ||= stub('commit', :branch => 'master') end
end

describe Travis::Model::Request do
  let(:payload) { GITHUB_PAYLOADS['gem-release'] }
  let(:record)  { Request.new }

  before :each do
    ::Request.stubs(:create_from).returns(record)
  end

  describe '.create' do
    it 'creates a Request record' do
      ::Request.expects(:create_from).returns(record)
      Travis::Model::Request.create(payload)
    end

    it 'instantiates a new Request with the record' do
      Travis::Model::Request.create(payload).record.should == record
    end

    it 'sets the state :created to the record' do
      record.expects(:state=).with(:created)
      Travis::Model::Request.create(payload)
    end
  end

  describe 'events' do
    let(:request) { Travis::Model::Request.create(payload) }

    it 'has the state :created when just created' do
      request.state.should == :created
    end

    describe 'start!' do
      it 'changes the state to :started' do
        request.start!
        request.state.should == :started
      end

      it 'saves the record' do
        record.expects(:save!).times(2) # TODO why exactly do we save the record twice?
        request.start!
      end
    end

    describe 'configure!' do
      before :each do
        request.stubs(:approved?).returns(true)
        request.stubs(:build).returns(stub(:matrix => [stub('job', :state= => nil)]))
      end

      it 'changes the state to :finished (because it also finishes the request)' do
        request.configure!({ :rvm => 'rbx' })
        request.state.should == :finished
      end

      it 'saves the record' do
        record.expects(:save!).times(2)
        request.configure!({ :rvm => 'rbx' })
      end
    end

    describe 'finish!' do
      it 'changes the state to :finish' do
        request.finish!
        request.state.should == :finished
      end

      it 'saves the record' do
        record.expects(:save!).times(2)
        request.finish!
      end
    end
  end

  describe :approved? do
    let(:request) { Travis::Model::Request.new(record) }

    describe 'returns true' do
      it 'if there is no branches option' do
        request.record.stubs(:config).returns({})
        request.should be_approved
      end

      it 'if the branch is included the branches option given as a string' do
        request.record.stubs(:config).returns(:branches => 'master, develop')
        request.should be_approved
      end

      it 'if the branch is included in the branches option given as an array' do
        request.record.stubs(:config).returns(:branches => ['master', 'develop'])
        request.should be_approved
      end

      it 'if the branch is included in the branches :only option given as a string' do
        request.record.stubs(:config).returns(:branches => { :only => 'master, develop' })
        request.should be_approved
      end

      it 'if the branch is included in the branches :only option given as an array' do
        request.record.stubs(:config).returns(:branches => { :only => ['master', 'develop'] })
        request.should be_approved
      end

      it 'if the branch is not included in the branches :except option given as a string' do
        request.record.stubs(:config).returns(:branches => { :except => 'github-pages, feature-*' })
        request.should be_approved
      end

      it 'if the branch is not included in the branches :except option given as an array' do
        request.record.stubs(:config).returns(:branches => { :except => ['github-pages', 'feature-*'] })
        request.should be_approved
      end
    end

    describe 'returns false' do
      before(:each) { request.record.commit.stubs(:branch).returns('staging') }

      it 'if the branch is not included the branches option given as a string' do
        request.record.stubs(:config).returns(:branches => 'master, develop')
        request.should_not be_approved
      end

      it 'if the branch is not included in the branches option given as an array' do
        request.record.stubs(:config).returns(:branches => ['master', 'develop'])
        request.should_not be_approved
      end

      it 'if the branch is not included in the branches :only option given as a string' do
        request.record.stubs(:config).returns(:branches => { :only => 'master, develop' })
        request.should_not be_approved
      end

      it 'if the branch is not included in the branches :only option given as an array' do
        request.record.stubs(:config).returns(:branches => { :only => ['master', 'develop'] })
        request.should_not be_approved
      end

      it 'if the branch is included in the branches :except option given as a string' do
        request.record.stubs(:config).returns(:branches => { :except => 'staging, feature-*' })
        request.should_not be_approved
      end

      it 'if the branch is included in the branches :except option given as an array' do
        request.record.stubs(:config).returns(:branches => { :except => ['staging', 'feature-*'] })
        request.should_not be_approved
      end
    end
  end
end
