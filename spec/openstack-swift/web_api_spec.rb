# -*- coding: UTF-8 -*-
require "spec_helper"

describe Openstack::Swift::WebApi do
  context "when authenticating" do
    it "should authenticate on swift" do
      expect {
        subject.auth(Openstack::SwiftConfig[:url], Openstack::SwiftConfig[:user], Openstack::SwiftConfig[:pass])
      }.to_not raise_error Openstack::Swift::AuthenticationError
    end

    it "should raise error for a invalid url" do
      expect {
        subject.auth("http://pothix.com/swift", Openstack::SwiftConfig[:user], Openstack::SwiftConfig[:pass])
      }.to raise_error Openstack::Swift::AuthenticationError
    end

    it "should raise error for a invalid pass" do
      expect {
        subject.auth(Openstack::SwiftConfig[:url], Openstack::SwiftConfig[:user], "invalidpassword")
      }.to raise_error Openstack::Swift::AuthenticationError
    end

    it "should raise error for a invalid user" do
      expect {
        subject.auth(Openstack::SwiftConfig[:url], "system:weirduser", Openstack::SwiftConfig[:pass])
      }.to raise_error Openstack::Swift::AuthenticationError
    end

    it "should return storage-url, storage-token and auth-token" do
      subject.auth(Openstack::SwiftConfig[:url], Openstack::SwiftConfig[:user], Openstack::SwiftConfig[:pass]).should have(3).items
    end
  end

  context "when authenticated" do
    let!(:swift_dummy_file){ File.open("/tmp/swift-dummy", "w") {|f| f.puts("test file"*1000)} }

    before do
      @url, _, @token = subject.auth(
        Openstack::SwiftConfig[:url],
        Openstack::SwiftConfig[:user],
        Openstack::SwiftConfig[:pass]
      )
    end

    it "should return account's headers" do
      account = subject.account(@url, @token)
      account.should have_key("x-account-bytes-used")
      account.should have_key("x-account-object-count")
      account.should have_key("x-account-container-count")
    end

    it "should return a list of containers" do
      subject.containers(@url, @token).should be_a(Array)
    end

    it "should return a list of objects" do
      subject.objects(@url, @token, "morellon", :delimiter => "/").should be_a(Array)
    end

    it "should download an object" do
      subject.download_object(@url, @token, "morellon", "Gemfile").should == "/tmp/swift/morellon/Gemfile"
    end

    it "should upload an object" do
      subject.upload_object(@url, @token, "morellon", "/tmp/swift-dummy").code.should == "201"
    end

    it "should create a new container" do
      subject.create_container(@url, @token, "pothix_container").should be_true
    end

    context "when excluding a container" do
      before { @container = "pothix_container" }
      it "should delete a existent container" do
        subject.create_container(@url, @token, @container).should be_true
        subject.delete_container(@url, @token, @container).should be_true
      end

      it "should raise an error when the container doesn't exist" do
        expect {
          subject.delete_container(@url, @token, @container).should be_true
          subject.delete_container(@url, @token, @container).should be_true
        }.to raise_error("Could not delete container '#{@container}'")
      end
    end

    it "should get the file stat" do
      subject.upload_object(@url, @token, "morellon", "/tmp/swift-dummy")
      headers = subject.object_stat(@url, @token, "morellon", "swift-dummy")

      headers["last-modified"].should_not be_blank
      headers["etag"].should_not be_blank
      headers["content-type"].should_not be_blank
      headers["date"].should_not be_blank
    end
  end
end
