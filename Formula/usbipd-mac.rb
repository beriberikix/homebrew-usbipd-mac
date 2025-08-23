# typed: true
# frozen_string_literal: true

class UsbipdMac < Formula
  desc "Macos implementation of the usb/ip protocol"
  homepage "https://github.com/beriberikix/usbipd-mac"
  url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.30/usbipd-v0.1.30-macos"
   version "0.1.30"
  sha256 "acbd7a72d6b5458b7f8b2a4aa8362548598b0a5ccf842f244fcf688723f0c235"

  # System extension resource
  resource "systemextension" do
    url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.26/USBIPDSystemExtension.systemextension.tar.gz"
    sha256 "acbd7a72d6b5458b7f8b2a4aa8362548598b0a5ccf842f244fcf688723f0c235"
  end

  depends_on :macos => :big_sur

  def install
    bin.install "usbipd-v0.1.30-macos" => "usbipd"
    
    # Install system extension bundle
    resource("systemextension").stage do
      # Create system extension directory in expected Library/SystemExtensions path
      (prefix/"Library/SystemExtensions").mkpath
      
      # The tar.gz extracts to just "Contents" directory, so we need to reconstruct the bundle
      if Dir.exist?("Contents")
        puts "Found Contents directory, reconstructing system extension bundle..."
        bundle_dir = prefix/"Library/SystemExtensions"/"USBIPDSystemExtension.systemextension"
        bundle_dir.mkpath
        cp_r "Contents", bundle_dir
        puts "System extension bundle created at: #{bundle_dir}"
      elsif Dir.glob("*.systemextension").any?
        # If we have a .systemextension directory, copy it directly
        Dir.glob("*.systemextension") do |bundle|
          puts "Found system extension bundle: #{bundle}"
          cp_r bundle, prefix/"Library/SystemExtensions"
        end
      else
        puts "Warning: No system extension bundle found in staged directory"
        puts "Contents: #{Dir.glob('*').inspect}"
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
    puts "  1. Install the system extension:"
    puts "     sudo usbipd install-system-extension"
    puts
    puts "  2. Start the service:"
    puts "     sudo brew services start usbipd-mac"
    puts
    puts "  3. Approve the system extension in:"
    puts "     System Preferences → Security & Privacy → General"
    
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
    assert_path_exists "#{prefix}/Library/SystemExtensions/USBIPDSystemExtension.systemextension"
  end
end