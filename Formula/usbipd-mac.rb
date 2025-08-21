# typed: true
# frozen_string_literal: true

class UsbipdMac < Formula
  desc "Macos implementation of the usb/ip protocol"
  homepage "https://github.com/beriberikix/usbipd-mac"
  url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.19/usbipd-v0.1.19-macos"
  version "0.1.19"
  sha256 "0ef14acd5f91a291bdfa3f1c6a7564ae17a5e1aa5b40ebce6ab1479b294fafef"

  depends_on :macos => :big_sur

  def install
    bin.install "usbipd-v0.1.19-macos" => "usbipd"
  end

  test do
    assert_match "USB/IP Daemon for macOS", shell_output("#{bin}/usbipd --version")
  end
end
