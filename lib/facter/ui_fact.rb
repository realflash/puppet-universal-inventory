# Modified code originally written by
# Cody Herriges <cody@puppetlabs.com>
#
# Collects and creates a fact for every package installed on the system and
# returns that package's version as the fact value.  Useful for doing package
# inventory and making decisions based on installed package versions.


module UIDiscover
  def self.package_list
    packages = []
    case Facter.fact :operatingsystem
    when 'Debian', 'Ubuntu', 'LinuxMint'
      command = 'dpkg-query -W'
      packages = []
      Facter::Util::Resolution.exec(command).each_line do |pkg|
        packages << pkg.chomp.split("\t")
      end
    when 'CentOS', 'RedHat', 'Fedora'
      command = 'rpm -qa --qf %{NAME}"\t"%{VERSION}-%{RELEASE}"\n"'
      packages = []
      Facter::Util::Resolution.exec(command).each_line do |pkg|
        packages << pkg.chomp.split("\t")
      end
    # I don't have any Solaris boxes to test this on but if someone
    # wants to do that I don't mind listing it as a supported platform
    when 'Solaris'
      command = 'pkginfo -x'
      combined = ''
      packages = []
      Facter::Util::Resolution.exec(command).each_line do |line|
        if line =~ /^\w/
          combined << line.chomp
        else
          combined << line
        end
      end
      combined.each_line do |pkg|
        packages << pkg.chomp.scan(/^(\S+).*\s(\d.*)/)[0]
      end
    end
    return packages
  end
end

UIDiscover.package_list.each do |key, value|
  Facter.add(:"pkg_#{key}") do
    confine :operatingsystem => ['CentOS', 'Fedora', 'Redhat', 'Debian', 'Ubuntu', 'LinuxMint']
    setcode do
      value
    end
  end
end
