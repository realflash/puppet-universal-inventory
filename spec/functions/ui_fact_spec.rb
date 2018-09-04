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
		e.response = 'accountsservice	0.6.40-2ubuntu11.3
acl	2.2.52-3
acpi-support	0.142'
		it 'handles well-formed UTF-8 package data' do
			expect(UIDiscover.package_list(e)).to eql([{"installed_version"=>"0.6.40-2ubuntu11.3", "name"=>"accountsservice"}, {"installed_version"=>"2.2.52-3", "name"=>"acl"}, {"installed_version"=>"0.142", "name"=>"acpi-support"}])
		end
	end
end

