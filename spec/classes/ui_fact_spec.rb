require 'spec_helper'
require 'facter/ui_fact'
describe 'UIDiscover' do
	class ExecutorStub
		attr_accessor :response
		def exec(command)
			return response
		end
	end

	e = ExecutorStub.new

	describe 'package_list' do
		context 'when linux' do
			#~ let(:facts) { {'operatingsystem' => 'Debian'} }	# Doesn't work
			it 'handles well-formed UTF-8 package data' do
				e.response = 'accountsservice	0.6.40-2ubuntu11.3
acl	2.2.52-3
acpi-support	0.142'
				expect(UIDiscover.package_list(e, "Debian")).to eql([{"installed_version"=>"0.6.40-2ubuntu11.3", "name"=>"accountsservice"}, {"installed_version"=>"2.2.52-3", "name"=>"acl"}, {"installed_version"=>"0.142", "name"=>"acpi-support"}])
			end
		end
		context 'when windows' do
			#~ let(:facts) { {'operatingsystem' => 'windows'} }
			it 'handles well-formed UTF-8 package data' do
  				e.response = '
Node,Name,Vendor,Version
IGIBBS-W10-VM-W,Office 16 Click-to-Run Extensibility Component,Microsoft Corporation,16.0.10730.20088
IGIBBS-W10-VM-W,Office 16 Click-to-Run Localization Component,Microsoft Corporation,16.0.10730.20088
IGIBBS-W10-VM-W,Office 16 Click-to-Run Extensibility Component 64-bit Registration,Microsoft Corporation,16.0.10730.20088'
				expect(UIDiscover.package_list(e, "windows")).to eql([{"installed_version"=>"0.6.40-2ubuntu11.3", "name"=>"accountsservice"}, {"installed_version"=>"2.2.52-3", "name"=>"acl"}, {"installed_version"=>"0.142", "name"=>"acpi-support"}])
			end
		end
	end
end

