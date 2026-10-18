# frozen_string_literal: true

control 'Apt repositories' do
  title 'should be configured'

  codename = { '11' => 'bullseye', '13' => 'trixie' }[os[:release].split('.').first]

  describe package('debian-archive-keyring') do
    it { should be_installed }
  end

  describe file('/etc/apt/sources.list') do
    it { should exist }
    its(:size) { should eq 0 }
  end

  describe file('/etc/apt/sources.list.d') do
    it { should be_directory }
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
    its('mode') { should cmp '0755' }
  end

  describe file('/etc/apt/sources.list.d/unmanaged.list') do
    it { should exist }
    its(:content) do
      should match("## unmanged list file that shouldn't be removed")
    end
  end

  # Shipped by the Salt image, not managed: removed by `clean_sources_list_d`
  describe file('/etc/apt/sources.list.d/salt.sources') do
    it { should_not exist }
  end

  describe file('/etc/apt/sources.list.d/debian.sources') do
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
    its('mode') { should cmp '0644' }
    its(:content) do
      should eq <<~SOURCES
        Types: deb
        URIs: http://deb.debian.org/debian
        Suites: #{codename}
        Components: main
        Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
      SOURCES
    end
  end

  describe file('/etc/apt/sources.list.d/saltstack.sources') do
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
    its('mode') { should cmp '0644' }
    its(:content) do
      should eq <<~SOURCES
        Types: deb
        URIs: https://packages.broadcom.com/artifactory/saltproject-deb
        Suites: stable
        Components: main
        Signed-By: /etc/apt/keyrings/salt-archive-keyring.pgp
      SOURCES
    end
  end

  describe file('/etc/apt/keyrings/salt-archive-keyring.pgp') do
    it { should exist }
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
    its('mode') { should cmp '0644' }
  end
end
