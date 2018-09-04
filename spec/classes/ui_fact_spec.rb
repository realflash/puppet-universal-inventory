require 'spec_helper'
require 'facter/ui_fact'
describe 'UIDiscover' do
	class ExecutorStub
		attr_accessor :response
		def exec(command)
			return response
		end
	end

	describe 'package_list' do
		context 'on APT distros' do
			#~ let(:facts) { {'operatingsystem' => 'Debian'} }	# Doesn't work
			e = ExecutorStub.new
			e.response = 'accountsservice	0.6.40-2ubuntu11.3
acl	2.2.52-3
acpi-support	0.142'
			apt_pkg_hash = [
				{"installed_version"=>"0.6.40-2ubuntu11.3", "name"=>"accountsservice"},
				{"installed_version"=>"2.2.52-3", "name"=>"acl"},
				{"installed_version"=>"0.142", "name"=>"acpi-support"}
			]
			it 'retrieves packages on Debian' do
				expect(UIDiscover.package_list(e, "Debian")).to eql([
				{"installed_version"=>"0.6.40-2ubuntu11.3", "name"=>"accountsservice"},
				{"installed_version"=>"2.2.52-3", "name"=>"acl"},
				{"installed_version"=>"0.142", "name"=>"acpi-support"}
			])
			end
			it 'retrieves packages on Ubuntu' do
				expect(UIDiscover.package_list(e, "Ubuntu")).to eql(apt_pkg_hash)
			end
			it 'retrieves packages on Linux Mint' do
				expect(UIDiscover.package_list(e, "Ubuntu")).to eql(apt_pkg_hash)
			end
		end
		context 'on RPM distros' do
			#~ let(:facts) { {'operatingsystem' => 'CentOS'} }	# Doesn't work
			e = ExecutorStub.new
			e.response = 'dbus-glib	0.100-7.el7
redhat-release-server	7.5-8.el7
setup	2.8.71-9.el7'
			rpm_pkg_hash = [
					{"installed_version"=>"0.100-7.el7", "name"=>"dbus-glib"},
					{"installed_version"=>"7.5-8.el7", "name"=>"redhat-release-server"},
					{"installed_version"=>"2.8.71-9.el7", "name"=>"setup"}
			]
			it 'retrieves packages on CentOS' do
				expect(UIDiscover.package_list(e, "CentOS")).to eql(rpm_pkg_hash)
			end
			it 'retrieves packages on RedHat' do
				expect(UIDiscover.package_list(e, "RedHat")).to eql(rpm_pkg_hash)
			end
			it 'retrieves packages on Fedora' do
				expect(UIDiscover.package_list(e, "Fedora")).to eql(rpm_pkg_hash)
			end
			it 'retrieves packages on Amazon' do
				expect(UIDiscover.package_list(e, "Fedora")).to eql(rpm_pkg_hash)
			end
			it 'retrieves packages on OracleLinux' do
				expect(UIDiscover.package_list(e, "Fedora")).to eql(rpm_pkg_hash)
			end
			it 'retrieves packages on Scientific' do
				expect(UIDiscover.package_list(e, "Fedora")).to eql(rpm_pkg_hash)
			end
			it 'retrieves packages on SLES' do
				expect(UIDiscover.package_list(e, "Fedora")).to eql(rpm_pkg_hash)
			end
		end
		context 'on windows' do
			#~ let(:facts) { {'operatingsystem' => 'windows'} }	# doesn't work
			e = ExecutorStub.new
			e.response = '
Node,Name,Vendor,Version
IGIBBS-W10-VM-W,Office 16 Click-to-Run Extensibility Component,Microsoft Corporation,16.0.10730.20088
IGIBBS-W10-VM-W,Office 16 Click-to-Run Localization Component,Microsoft Corporation,16.0.10730.20088
IGIBBS-W10-VM-W,Google Update Helper,Google, Inc.,1.3.33.17'
			
			msi_pkg_hash = [
					{"installed_version"=>"16.0.10730.20088", "name"=>"Office 16 Click-to-Run Extensibility Component", "vendor"=>"Microsoft Corporation"},
					{"installed_version"=>"16.0.10730.20088", "name"=>"Office 16 Click-to-Run Localization Component", "vendor"=>"Microsoft Corporation"},
					{"installed_version"=>"1.3.33.17", "name"=>"Google Update Helper", "vendor"=>"Google, Inc."}
				]
			it 'retrieves packages when the data is well-formed' do
				expect(UIDiscover.package_list(e, "windows")).to eql(msi_pkg_hash)
			end
			e2 = ExecutorStub.new
			e2.response = "
Node,Name,Vendor,Version
IGIBBS-W10-VM-W,Office 16 Click-to-Run Extensibility Component\255,Microsoft Corporation,16.0.10730.20088
IGIBBS-W10-VM-W,Office 16 Click-to-Run Localization Component,Microsoft Corporation,16.0.10730.20088
IGIBBS-W10-VM-W,Google Update Helper,Google, Inc.,1.3.33.17"
			it 'retrieves packages when the data contains an invalid UTF-8 byte sequence' do
				expect(UIDiscover.package_list(e2, "windows")).to eql(msi_pkg_hash)
			end
		end
		context 'on OS X' do
			#~ let(:facts) { {'operatingsystem' => 'Darwin'} }
			e = ExecutorStub.new
			e.response = '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
	<dict>
		<key>_SPCommandLineArguments</key>
		<array>
			<string>/usr/sbin/system_profiler</string>
			<string>-nospawn</string>
			<string>-xml</string>
			<string>SPApplicationsDataType</string>
			<string>-detailLevel</string>
			<string>full</string>
		</array>
		<key>_SPCompletionInterval</key>
		<real>2.8157670497894287</real>
		<key>_SPResponseTime</key>
		<real>2.9305260181427002</real>
		<key>_dataType</key>
		<string>SPApplicationsDataType</string>
		<key>_detailLevel</key>
		<integer>1</integer>
		<key>_items</key>
		<array>
			<dict>
				<key>_name</key>
				<string>Microsoft Excel</string>
				<key>has64BitIntelCode</key>
				<string>yes</string>
				<key>info</key>
				<string>16.16.1 (180814 :2), © 2018 Microsoft Corporation. All rights reserved.</string>
				<key>lastModified</key>
				<date>2018-08-29T14:08:18Z</date>
				<key>obtained_from</key>
				<string>identified_developer</string>
				<key>path</key>
				<string>/Applications/Microsoft Excel.app</string>
				<key>runtime_environment</key>
				<string>arch_x86</string>
				<key>signed_by</key>
				<array>
					<string>Developer ID Application: Microsoft Corporation (UBF8T346G9)</string>
					<string>Developer ID Certification Authority</string>
					<string>Apple Root CA</string>
				</array>
				<key>version</key>
				<string>16.16.1</string>
			</dict>
			<dict>
				<key>_name</key>
				<string>Microsoft Outlook</string>
				<key>has64BitIntelCode</key>
				<string>yes</string>
				<key>info</key>
				<string>16.16 (180812 :1), © 2018 Microsoft Corporation. All rights reserved.</string>
				<key>lastModified</key>
				<date>2018-08-29T14:06:52Z</date>
				<key>obtained_from</key>
				<string>identified_developer</string>
				<key>path</key>
				<string>/Applications/Microsoft Outlook.app</string>
				<key>runtime_environment</key>
				<string>arch_x86</string>
				<key>signed_by</key>
				<array>
					<string>Developer ID Application: Microsoft Corporation (UBF8T346G9)</string>
					<string>Developer ID Certification Authority</string>
					<string>Apple Root CA</string>
				</array>
				<key>version</key>
				<string>16.16</string>
			</dict>
			<dict>
				<key>_name</key>
				<string>GoToMeeting</string>
				<key>has64BitIntelCode</key>
				<string>yes</string>
				<key>info</key>
				<string>GoToMeeting v8.33.0.9250, Copyright © 2018 LogMeIn, Inc.</string>
				<key>lastModified</key>
				<date>2018-09-03T09:46:00Z</date>
				<key>obtained_from</key>
				<string>identified_developer</string>
				<key>path</key>
				<string>/Applications/GoToMeeting.app</string>
				<key>runtime_environment</key>
				<string>arch_x86</string>
				<key>signed_by</key>
				<array>
					<string>Developer ID Application: LogMeIn, Inc. (GFNFVT632V)</string>
					<string>Developer ID Certification Authority</string>
					<string>Apple Root CA</string>
				</array>
				<key>version</key>
				<string>8.33.0.9250</string>
			</dict>
		</array>
		<key>_parentDataType</key>
		<string>SPSoftwareDataType</string>
		<key>_properties</key>
		<dict>
			<key>_name</key>
			<dict>
				<key>_isColumn</key>
				<string>YES</string>
				<key>_order</key>
				<string>0</string>
			</dict>
			<key>has64BitIntelCode</key>
			<dict>
				<key>_isColumn</key>
				<string>YES</string>
				<key>_order</key>
				<string>40</string>
			</dict>
			<key>lastModified</key>
			<dict>
				<key>_isColumn</key>
				<string>YES</string>
				<key>_order</key>
				<string>20</string>
			</dict>
			<key>obtained_from</key>
			<dict>
				<key>_isColumn</key>
				<string>YES</string>
				<key>_order</key>
				<string>15</string>
			</dict>
			<key>path</key>
			<dict>
				<key>_order</key>
				<string>90</string>
			</dict>
			<key>runtime_environment</key>
			<dict>
				<key>_order</key>
				<string>30</string>
			</dict>
			<key>signed_by</key>
			<dict>
				<key>_order</key>
				<string>60</string>
			</dict>
			<key>version</key>
			<dict>
				<key>_isColumn</key>
				<string>YES</string>
				<key>_order</key>
				<string>10</string>
			</dict>
			<key>volumes</key>
			<dict>
				<key>_detailLevel</key>
				<string>0</string>
			</dict>
		</dict>
		<key>_timeStamp</key>
		<date>2018-09-04T14:47:37Z</date>
		<key>_versionInfo</key>
		<dict>
			<key>com.apple.SystemProfiler.SPApplicationsReporter</key>
			<string>915</string>
		</dict>
	</dict>
</array>
</plist>
'
			osx_pkg_hash = [
					{"installed_version"=>"16.16.1", "name"=>"Microsoft Excel"},
					{"installed_version"=>"16.16", "name"=>"Microsoft Outlook"},
					{"installed_version"=>"8.33.0.9250", "name"=>"GoToMeeting"}
				]
			it 'handles well-formed UTF-8 package data' do
				expect(UIDiscover.package_list(e, "Darwin")).to eql(osx_pkg_hash)
			end
		end
	end
end
