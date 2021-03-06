require "spec_helper"

RSpec.describe "Rollout::Legacy" do
  before do
    @redis   = Redis.new
    @rollout = Rollout::Legacy.new(@redis)
  end

  describe "when a group is activated" do
    before do
      @rollout.define_group(:fivesonly) { |user| user.id == 5 }
      @rollout.activate_group(:chat, :fivesonly)
    end

    it "the feature is active for users for which the block evaluates to true" do
      expect(@rollout).to be_active(:chat, double(id: 5))
    end

    it "is not active for users for which the block evaluates to false" do
      expect(@rollout).not_to be_active(:chat, double(id: 1))
    end

    it "is not active if a group is found in Redis but not defined in Rollout" do
      @rollout.activate_group(:chat, :fake)
      expect(@rollout).not_to be_active(:chat, double(id: 1))
    end
  end

  describe "the default all group" do
    before do
      @rollout.activate_group(:chat, :all)
    end

    it "evaluates to true no matter what" do
      expect(@rollout).to be_active(:chat, double(id: 0))
    end
  end

  describe "deactivating a group" do
    before do
      @rollout.define_group(:fivesonly) { |user| user.id == 5 }
      @rollout.activate_group(:chat, :all)
      @rollout.activate_group(:chat, :fivesonly)
      @rollout.deactivate_group(:chat, :all)
    end

    it "deactivates the rules for that group" do
      expect(@rollout).not_to be_active(:chat, double(id: 10))
    end

    it "leaves the other groups active" do
      expect(@rollout).to be_active(:chat, double(id: 5))
    end
  end

  describe "deactivating a feature completely" do
    before do
      @rollout.define_group(:fivesonly) { |user| user.id == 5 }
      @rollout.activate_group(:chat, :all)
      @rollout.activate_group(:chat, :fivesonly)
      @rollout.activate_user(:chat, double(id: 51))
      @rollout.activate_percentage(:chat, 100)
      @rollout.activate_globally(:chat)
      @rollout.deactivate_all(:chat)
    end

    it "removes all of the groups" do
      expect(@rollout).not_to be_active(:chat, double(id: 0))
    end

    it "removes all of the users" do
      expect(@rollout).not_to be_active(:chat, double(id: 51))
    end

    it "removes the percentage" do
      expect(@rollout).not_to be_active(:chat, double(id: 24))
    end

    it "removes globally" do
      expect(@rollout).not_to be_active(:chat)
    end
  end

  describe "activating a specific user" do
    before do
      @rollout.activate_user(:chat, double(id: 42))
    end

    it "is active for that user" do
      expect(@rollout).to be_active(:chat, double(id: 42))
    end

    it "remains inactive for other users" do
      expect(@rollout).not_to be_active(:chat, double(id: 24))
    end
  end

  describe "deactivating a specific user" do
    before do
      @rollout.activate_user(:chat, double(id: 42))
      @rollout.activate_user(:chat, double(id: 24))
      @rollout.deactivate_user(:chat, double(id: 42))
    end

    it "that user should no longer be active" do
      expect(@rollout).not_to be_active(:chat, double(id: 42))
    end

    it "remains active for other active users" do
      expect(@rollout).to be_active(:chat, double(id: 24))
    end
  end

  describe "activating a feature globally" do
    before do
      @rollout.activate_globally(:chat)
    end

    it "activates the feature" do
      expect(@rollout).to be_active(:chat)
    end
  end

  describe "activating a feature for a percentage of users" do
    before do
      @rollout.activate_percentage(:chat, 20)
    end

    it "activates the feature for that percentage of the users" do
      expect((1..120).select { |id| @rollout.active?(:chat, double(id: id)) }.length).to eq(39)
    end
  end

  describe "activating a feature for a percentage of users" do
    before do
      @rollout.activate_percentage(:chat, 20)
    end

    it "activates the feature for that percentage of the users" do
      expect((1..200).select { |id| @rollout.active?(:chat, double(id: id)) }.length).to eq(40)
    end
  end

  describe "activating a feature for a percentage of users" do
    before do
      @rollout.activate_percentage(:chat, 5)
    end

    it "activates the feature for that percentage of the users" do
      expect((1..100).select { |id| @rollout.active?(:chat, double(id: id)) }.length).to eq(5)
    end
  end


  describe "deactivating the percentage of users" do
    before do
      @rollout.activate_percentage(:chat, 100)
      @rollout.deactivate_percentage(:chat)
    end

    it "becomes inactivate for all users" do
      expect(@rollout).not_to be_active(:chat, double(id: 24))
    end
  end

  describe "deactivating the feature globally" do
    before do
      @rollout.activate_globally(:chat)
      @rollout.deactivate_globally(:chat)
    end

    it "becomes inactivate" do
      expect(@rollout).not_to be_active(:chat)
    end
  end

  describe "#info" do
    context "global features" do
      let(:features) { [:signup, :chat, :table] }

      before do
        features.each do |f|
          @rollout.activate_globally(f)
        end
      end

      it "returns all global features" do
        expect(@rollout.info[:global]).to include(*features)
      end
    end

    describe "with a percentage set" do
      before do
        @rollout.activate_percentage(:chat, 10)
        @rollout.activate_group(:chat, :caretakers)
        @rollout.activate_group(:chat, :greeters)
        @rollout.activate_globally(:signup)
        @rollout.activate_user(:chat, double(id: 42))
      end

      it "returns info about all the activations" do
        info = @rollout.info(:chat)
        expect(info[:percentage]).to eq(10)
        expect(info[:groups]).to include(:caretakers, :greeters)
        expect(info[:users]).to include(42)
        expect(info[:global]).to include(:signup)
      end
    end

    describe "without a percentage set" do
      it "defaults to 0" do
        expect(@rollout.info(:chat)).to eq(
          percentage: 0,
          groups: [],
          users: [],
          global: [],
        )
      end
    end
  end
end
