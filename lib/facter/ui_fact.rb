# Ian Gibbs
#
# Built from code written by
# Cody Herriges <cody@puppetlabs.com>
# jhaals/app_inventory
#
# Collects and creates a fact for every package installed on the system and
# returns that package's version as the fact value.  Useful for doing package
# inventory and making decisions based on installed package versions.

module UIDiscover
require 'rexml/document'
require 'json'
require 'puppet'
include REXML
#~ attr_accessor :executor

  #~ def self.executor
	#~ @executor ||= UIExecute.new
  #~ end

  def self.parse(element)
    case element.name
    when 'array'
      element.elements.map {|child| parse(child)}
    when 'dict'
      result = {}
      element.elements.each_slice(2) do |key, value|
        result[key.text] = parse(value)
      end
      result
    when 'real'
      element.text.to_f
    when 'integer'
      element.text.to_i
    when 'string', 'date'
      element.text
    else
      # FIXME: Remove me or beef me up
      # puts "Unknown type " + element.name
    end
  end

  def self.package_list(executor = UIExecute.new, os = Facter.value(:operatingsystem))
    packages = []
    case os
    when 'Debian', 'Ubuntu', 'LinuxMint'
      command = 'dpkg-query -W'
      packages = []
      executor.exec(command).each_line do |pkg|
        pkg_parts = pkg.chomp.split("\t")
		puts "======================= HELLO =========================="
        packages << { "name" => pkg_parts[0], "installed_version" => pkg_parts[1] }
      end
    when 'CentOS', 'RedHat', 'Fedora', 'Amazon', 'OracleLinux', 'Scientific', 'SLES'
      command = 'rpm -qa --qf %{NAME}"\t"%{VERSION}-%{RELEASE}"\n"'
      packages = []
      Facter::Util::Resolution.exec(command).each_line do |pkg|
        pkg_parts = pkg.chomp.split("\t")
        packages << { "name" => pkg_parts[0], "installed_version" => pkg_parts[1] }
      end
	when 'windows'
	  command = 'wmic product WHERE (InstallState=5) get Name,Version,Vendor /format:csv'
      Facter::Util::Resolution.exec(command).each_line do |pkg|
	    pkg_string = pkg.chomp.chomp						# God knows why, but each line of output from the command ends in \r\r\n
		next if pkg_string == "Node,Name,Vendor,Version"	# Ignore the header row
        pkg_parts = pkg_string.split(",")
		# 0: computer name
		# 1: MSI name
		# Everything in between: vendor name complete with stray commas such "My Corp, Inc."
		# Last: MSI version
        packages << { "name" => pkg_parts[1], "installed_version" => pkg_parts[pkg_parts.length-1], "vendor" => pkg_parts[2..pkg_parts.length-2].join(',') }
      end
  when 'Darwin'
    command = 'system_profiler SPApplicationsDataType -xml'
    xml = Facter::Util::Resolution.exec(command)
    xmldoc = Document.new(xml)
    result = parse(xmldoc.root[1])

    packages = []
    result[0]['_items'].each do |application|
      # Only list applications in /Applications, Skip /Application/Utilities
      if application['path'].match(/^\/Applications/) and application['path'].index('Utilities') == nil
        if !application['version'].nil?
          packages << { "name" => application['_name'], "installed_version" => application['version'] }
        end
      end
    end
    # I don't have any Solaris boxes to test this on but if someone
    # wants to do that I don't mind listing it as a supported platform
    # Needs updating to provide response in structured format
  #~ when 'Solaris'
      #~ command = 'pkginfo -x'
      #~ combined = ''
      #~ packages = []
      #~ Facter::Util::Resolution.exec(command).each_line do |line|
        #~ if line =~ /^\w/
          #~ combined << line.chomp
        #~ else
          #~ combined << line
        #~ end
      #~ end
      #~ combined.each_line do |pkg|
        #~ packages << pkg.chomp.scan(/^(\S+).*\s(\d.*)/)[0]
      #~ end
    else
      packages = "Unsupported OS '" + Facter.value(:operatingsystem) + "'. Please report the output of `facter operatingsystem` at https://github.com/realflash/puppet-universal-inventory/issues"
    end
    return packages
  end
end

Facter.add(:"inventory") do
  setcode do
    JSON.generate(UIDiscover.package_list)
  end
end

class UIExecute
  def exec(command)
	return Facter::Util::Resolution.exec(command)
  end
end
  
