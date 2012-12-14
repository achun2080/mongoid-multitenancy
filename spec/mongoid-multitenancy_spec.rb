require "spec_helper"

describe Mongoid::Multitenancy do
  let(:client) { Client.create!(:name => "client") }
  let(:another_client) { Client.create!(:name => "another client") }

  before { Mongoid::Multitenancy.current_tenant = client }
  after { Mongoid::Multitenancy.current_tenant = nil }

  describe ".with_tenant" do
    it "should change temporary the current tenant within the block" do
      Mongoid::Multitenancy.with_tenant(another_client) do
        Mongoid::Multitenancy.current_tenant.should == another_client
      end
    end

    it "should have restored the current tenant after the block" do
      Mongoid::Multitenancy.with_tenant(another_client) do ; end
      Mongoid::Multitenancy.current_tenant.should == client
    end
  end
end

describe Article do
  it { should belong_to(:client) }
  it { should validate_presence_of(:client_id) }
  it { should validate_uniqueness_of(:slug).scoped_to(:client_id) }
  it { should have_index_for(:client_id => 1, :title => 1) }

  let(:client) { Client.create!(:name => "client") }
  let(:another_client) { Client.create!(:name => "another client") }

  describe ".initialize" do
    before { Mongoid::Multitenancy.current_tenant = client }
    after { Mongoid::Multitenancy.current_tenant = nil }

    it "should set the client field" do
      Article.new.client.should eq client
    end
  end

  describe ".default_scope" do
    before {
      Mongoid::Multitenancy.with_tenant(client) { @articleX = Article.create!(:title => "title X", :slug => "article-x") }
      Mongoid::Multitenancy.with_tenant(another_client) { @articleY = Article.create!(:title => "title Y", :slug => "article-y") }
    }

    context "with a current tenant" do
      before { Mongoid::Multitenancy.current_tenant = another_client }
      after { Mongoid::Multitenancy.current_tenant = nil }

      it "should filter on the current tenant" do
        Article.all.to_a.should == [@articleY]
      end
    end

    context "without a current tenant" do
      before { Mongoid::Multitenancy.current_tenant = nil }

      it "should not filter on any tenant" do
        Article.all.to_a.should == [@articleX, @articleY]
      end
    end
  end

  describe "#valid?" do
    before { Mongoid::Multitenancy.current_tenant = client }
    after { Mongoid::Multitenancy.current_tenant = nil }

    let(:article) { Article.create!(:title => "title X", :slug => "article-x") }

    context "when the tenant has not changed" do
      it 'should be valid' do
        article.title = "title X (2)"
        article.should be_valid
      end
    end

    context "when the tenant has changed" do
      it 'should be invalid' do
        article.title = "title X (2)"
        article.client = another_client
        article.should_not be_valid
      end
    end

  end

  describe "#delete_all" do
    before {
      Mongoid::Multitenancy.with_tenant(client) { @articleX = Article.create!(:title => "title X", :slug => "article-x") }
      Mongoid::Multitenancy.with_tenant(another_client) { @articleY = Article.create!(:title => "title Y", :slug => "article-y") }
    }

    context "with a current tenant" do
      it "should only delete the current tenant articles" do
        Mongoid::Multitenancy.with_tenant(another_client) { Article.delete_all }
        Article.all.to_a == [@articleX]
      end
    end

    context "without a current tenant" do
      it "should delete all the articles" do
        Article.delete_all
        Article.all.to_a.should be_empty
      end
    end
  end
end