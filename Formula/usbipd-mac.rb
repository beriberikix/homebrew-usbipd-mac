# typed: true
# frozen_string_literal: true

class UsbipdMac < Formula
  desc "Macos implementation of the usb/ip protocol"
  homepage "https://github.com/beriberikix/usbipd-mac"
  url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.26/usbipd-v0.1.26-macos"
  version "0.1.26"
  sha256 "d4ca2711899d15824b4f6a3b5d31e0e6ce039fe34676548617f11ed4b60d9466"

  # System extension resource
  resource "systemextension" do
    url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.26/USBIPDSystemExtension.systemextension.tar.gz"
    sha256 "551db5d58b51979d184585e11493f81d0d8276ac840302f2d5b6dbf50a46f395"
  end

  depends_on :macos => :big_sur

  def install
    bin.install "usbipd-v0.1.26-macos" => "usbipd"
    
    # Install system extension bundle
    resource("systemextension").stage do
      # Create system extension directory in Homebrew prefix
      (prefix/"SystemExtensions").mkpath
      # Copy the system extension bundle using Homebrew's preferred method
      cp_r "USBIPDSystemExtension.systemextension", prefix/"SystemExtensions"
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
    assert_path_exists "#{prefix}/SystemExtensions/USBIPDSystemExtension.systemextension"
  end
end