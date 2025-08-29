# typed: true
# frozen_string_literal: true

class Usbip < Formula
  desc "Macos implementation of the usb/ip protocol"
  homepage "https://github.com/beriberikix/usbipd-mac"
  url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.37-test/usbipd-v0.1.37-test-macos"
     version "0.1.37-test"
  sha256 "e682cba09ebcea5de044526e5f46d79ef3fc6a188ae62f7079f333901958f3c4"

  depends_on macos: :big_sur

  # System extension resource
  resource "systemextension" do
    url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.37-test/USBIPDSystemExtension.systemextension.tar.gz"
    sha256 "c7ad52775af9b27c5437446bd79f125869a2688f6cbae079f4b428f5f26c0b74"
  end

  def install
    bin.install "usbipd-v0.1.37-test-macos" => "usbipd"

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
        puts "Contents: #{Dir.glob("*").inspect}"
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
    puts "     sudo brew services start usbip"
    puts
    puts "  3. Approve the system extension in:"
    puts "     System Preferences → Security & Privacy → General"

    puts
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "  🐚 Shell Completions Available"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts
    puts "To install shell completions for enhanced CLI experience:"
    puts
    puts "  usbipd completion install"
    puts
    puts "This will install completion scripts for bash, zsh, and fish to your"
    puts "user directories. After installation, restart your shell or source"
    puts "the completion files to activate tab completion."
    puts
    puts "Alternatively, generate completions manually:"
    puts "  usbipd completion generate --shell bash > ~/.local/share/bash-completion/completions/usbipd"
    puts "  usbipd completion generate --shell zsh > ~/.zsh/completions/_usbipd"
    puts "  usbipd completion generate --shell fish > ~/.config/fish/completions/usbipd.fish"
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

    # Test that completion command works (basic functionality test)
    # This validates the core completion functionality
    assert_match "completion",
                 shell_output("#{bin}/usbipd completion --help")
  end
end