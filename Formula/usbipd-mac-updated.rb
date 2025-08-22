# typed: true
# frozen_string_literal: true

class UsbipdMac < Formula
  desc "Macos implementation of the usb/ip protocol"
  homepage "https://github.com/beriberikix/usbipd-mac"
  url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.25/usbipd-v0.1.25-macos"
  version "0.1.25"
  sha256 "9ad72f127f61d3cbd1c124215ae1db8f9dfeea007d76c164df4c5729d5737a00"

  # System extension resource (placeholder SHA256 - will be updated when system extension is available)
  resource "systemextension" do
    url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.25/USBIPDSystemExtension.systemextension.tar.gz"
    sha256 "PLACEHOLDER_SYSEXT_SHA256"
  end

  depends_on :macos => :big_sur

  def install
    bin.install "usbipd-v0.1.25-macos" => "usbipd"
    
    # Install system extension bundle if available
    if build.with?("systemextension") || File.exist?("USBIPDSystemExtension.systemextension.tar.gz")
      resource("systemextension").stage do
        # Create system extension directory in Homebrew prefix
        (prefix/"SystemExtensions").mkpath
        system "cp", "-R", "USBIPDSystemExtension.systemextension", "#{prefix}/SystemExtensions/"
      end
    end
  end

  def post_install
    puts
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "  🔧 Additional Setup Required"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts
    puts "To complete installation and enable system extension functionality:"
    puts
    
    if File.exist?("#{prefix}/SystemExtensions/USBIPDSystemExtension.systemextension")
      puts "  1. Install the system extension:"
      puts "     sudo usbipd install-system-extension"
      puts
      puts "  2. Start the service:"
      puts "     sudo brew services start usbipd-mac"
      puts
      puts "  3. Approve the system extension in:"
      puts "     System Preferences → Security & Privacy → General"
    else
      puts "  ⚠️  System Extension bundle not available in this release."
      puts "     You can still use basic functionality, but advanced features"
      puts "     require building from source or waiting for an updated release."
      puts
      puts "  1. Start the service:"
      puts "     sudo brew services start usbipd-mac"
    end
    
    puts
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts
  end

  service do
    run [opt_bin/"usbipd", "daemon"]
    keep_alive true
    require_root true
    log_path "/var/log/usbipd.log"
    error_log_path "/var/log/usbipd.error.log"
  end

  test do
    assert_match "USB/IP Daemon for macOS", shell_output("#{bin}/usbipd --version")
    
    # Test system extension presence if available
    if File.exist?("#{prefix}/SystemExtensions/USBIPDSystemExtension.systemextension")
      assert_path_exists "#{prefix}/SystemExtensions/USBIPDSystemExtension.systemextension"
    end
  end
end