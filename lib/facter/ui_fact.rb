# Modified code originally written by
# Cody Herriges <cody@puppetlabs.com>
#
# Collects and creates a fact for every package installed on the system and
# returns that package's version as the fact value.  Useful for doing package
# inventory and making decisions based on installed package versions.


module UIDiscover
  def self.package_list
    packages = []
    case Facter.value(:operatingsystem)
    when 'Debian', 'Ubuntu', 'LinuxMint'
      command = 'dpkg-query -W'
      packages = []
      Facter::Util::Resolution.exec(command).each_line do |pkg|
        pkg_parts = pkg.chomp.split("\t")
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
    UIDiscover.package_list
  end
end
