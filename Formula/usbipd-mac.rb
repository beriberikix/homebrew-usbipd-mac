# typed: true
# frozen_string_literal: true

class UsbipdMac < Formula
  desc "Macos implementation of the usb/ip protocol"
  homepage "https://github.com/beriberikix/usbipd-mac"
  url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.25/usbipd-v0.1.25-macos"
  version "0.1.25"
  sha256 "9ad72f127f61d3cbd1c124215ae1db8f9dfeea007d76c164df4c5729d5737a00"

  depends_on :macos => :big_sur

  def install
    bin.install "usbipd-v0.1.25-macos" => "usbipd"
  end

  test do
    assert_match "USB/IP Daemon for macOS", shell_output("#{bin}/usbipd --version")
  end
end
