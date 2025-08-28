# typed: true
# frozen_string_literal: true

class Usbip < Formula
  desc "Macos implementation of the usb/ip protocol"
  homepage "https://github.com/beriberikix/usbipd-mac"
  url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.34/usbipd-v0.1.34-macos"
  version "0.1.34"
  sha256 "08e9777c110a174987e8639d793722b9fe43d31c0ffa30eb32474c76cf19214d"

  depends_on macos: :big_sur

  # System extension resource
  resource "systemextension" do
    url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.34/USBIPDSystemExtension.systemextension.tar.gz"
    sha256 "3c255613d6063bfcae2c1d6c3acc2a3fdac041a9a443d340defe6d47759a450a"
  end

  def install
    bin.install "usbipd-v0.1.34-macos" => "usbipd"

    # Install shell completion scripts
    # For now, we'll install completion scripts that can be generated post-install
    # This avoids build-time issues with system extension dependencies
    
    # Create completion directory for post-install generation
    mkdir_p "completions"
    
    # Create a simple post-install completion script
    (buildpath/"completions"/"install-completions.sh").write <<~EOS
      #!/bin/bash
      # Post-install completion generation script for usbipd
      
      echo "Generating shell completion scripts..."
      if command -v usbipd >/dev/null 2>&1; then
          COMP_DIR="$HOME/.local/share/bash-completion/completions"
          ZSH_COMP_DIR="$HOME/.zsh/completions"  
          FISH_COMP_DIR="$HOME/.config/fish/completions"
          
          # Create completion directories
          mkdir -p "$COMP_DIR" "$ZSH_COMP_DIR" "$FISH_COMP_DIR"
          
          # Generate completion scripts using the generate subcommand
          mkdir -p /tmp/usbipd-completions
          usbipd completion generate --output /tmp/usbipd-completions 2>/dev/null
          
          # Copy generated scripts to user directories
          [ -f /tmp/usbipd-completions/usbipd ] && cp /tmp/usbipd-completions/usbipd "$COMP_DIR/usbipd"
          [ -f /tmp/usbipd-completions/_usbipd ] && cp /tmp/usbipd-completions/_usbipd "$ZSH_COMP_DIR/_usbipd"
          [ -f /tmp/usbipd-completions/usbipd.fish ] && cp /tmp/usbipd-completions/usbipd.fish "$FISH_COMP_DIR/usbipd.fish"
          
          # Clean up temporary directory
          rm -rf /tmp/usbipd-completions
          
          echo "✓ Shell completions installed to user directories"
          echo "  Bash: $COMP_DIR/usbipd"
          echo "  Zsh:  $ZSH_COMP_DIR/_usbipd"
          echo "  Fish: $FISH_COMP_DIR/usbipd.fish"
          echo ""
          echo "Restart your shell or source the completion files to activate."
      else
          echo "✗ usbipd command not found. Please ensure the binary is in your PATH."
      fi
    EOS
    
    chmod "+x", buildpath/"completions"/"install-completions.sh"
    
    # Install the completion generation script  
    bin.install "completions/install-completions.sh" => "usbipd-install-completions"

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
    puts "  usbipd-install-completions"
    puts
    puts "This will install completion scripts for bash, zsh, and fish to your"
    puts "user directories. After installation, restart your shell or source"
    puts "the completion files to activate tab completion."
    puts
    puts "Alternatively, generate completions manually:"
    puts "  usbipd completion bash > ~/.local/share/bash-completion/completions/usbipd"
    puts "  usbipd completion zsh > ~/.zsh/completions/_usbipd"
    puts "  usbipd completion fish > ~/.config/fish/completions/usbipd.fish"
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

    # Test that completion installation script exists
    assert_path_exists "#{bin}/usbipd-install-completions"
    
    # Test that the completion installation script is executable
    assert File.executable?("#{bin}/usbipd-install-completions")

    # Test that completion command works (basic functionality test)
    # This validates the core completion functionality
    assert_match "Completion Generation Summary",
                 shell_output("#{bin}/usbipd completion generate --output /tmp/test-completions 2>&1")
  end
end