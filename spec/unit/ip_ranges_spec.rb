require "ruby_vcloud_sdk/ip_ranges"

describe VCloudSdk::IpRanges do

  share_examples_for "VCloudSdk::IpRanges" do |ip_range_string, n|
    it "parses input string correctly" do
      ip_range = described_class.new(ip_range_string).ranges
      ip_range.should be_an_instance_of Array
      ip_range.should have(n).item
      ip_range.each do |i|
        i.should be_an_instance_of Range
        ip_range_start = i.first
        ip_range_end = i.last
        (ip_range_start.is_a?(NetAddr::CIDRv4) || ip_range_start.is_a?(NetAddr::CIDRv6))
          .should be_true
        (ip_range_end.is_a?(NetAddr::CIDRv4) || ip_range_end.is_a?(NetAddr::CIDRv6))
          .should be_true
        (ip_range_start > ip_range_end).should be_false
      end
    end
  end

  describe "#initialize" do
    context "valid input string" do
      context "a single IP address" do
        it_should_behave_like "VCloudSdk::IpRanges", "10.142.15.11", 1
        it_should_behave_like "VCloudSdk::IpRanges", "2001::", 1
      end

      context "input string uses '-' separator" do
        it_should_behave_like "VCloudSdk::IpRanges", "10.142.15.11 - 10.142.15.22", 1
        it_should_behave_like "VCloudSdk::IpRanges",
                              "2001:0db8:85a3:0000:0000:8a2e:0370:7334-2001:0db8:85a3:0000:0000:8a2e:0370:7339",
                              1
      end

      context "input string uses subnet mask" do
        it_should_behave_like "VCloudSdk::IpRanges", "10.142.15.0/24", 1
        it_should_behave_like "VCloudSdk::IpRanges", "fec0::/24", 1
        it_should_behave_like "VCloudSdk::IpRanges", "2001:0db8:85a3:0000:0000:8a2e:0370:7334/24", 1
      end

      context "input string uses comma separated IPs" do
        it_should_behave_like "VCloudSdk::IpRanges", "10.142.15.0, 10.142.15.4, 10.142.16.4", 3
        it_should_behave_like "VCloudSdk::IpRanges",
                              "fec0::, 2001:0db8:85a3:0000:0000:8a2e:0370:7334",
                              2
        it_should_behave_like "VCloudSdk::IpRanges", "fec0::/24, 10.142.15.4/23", 2
        it_should_behave_like "VCloudSdk::IpRanges", "10.142.15.11-10.142.15.22, 10.142.2.4, 10.142.16.4/23", 3
      end
    end

    context "invalid input" do
      context "not a string" do
        it "raises an error" do
          expect { described_class.new(["XX"]) }
            .to raise_exception "Unable to parse a non-string object"
        end
      end

      context "invalid string" do
        it "raises an error" do
          expect { described_class.new("XX") }
            .to raise_exception NetAddr::ValidationError, "Could not auto-detect IP version for 'XX'."
        end
      end

      context "Invalid IP address" do
        it "raises an error" do
          ip_range_string = "10.1.142.256"
          expect { described_class.new(ip_range_string) }
            .to raise_exception NetAddr::ValidationError
          ip_range_string = "10.1.142.252 - 10.1.142.256"
          expect { described_class.new(ip_range_string) }
            .to raise_exception NetAddr::ValidationError
        end
      end

      context "Incorrect separator" do
        it "raises an error" do
          ip_range_string = "10.1.142.255 - "
          expect { described_class.new(ip_range_string) }
            .to raise_exception "Invalid input: 1 field/fields separated by '-'"
          ip_range_string = "10.1.142.255 - 10.1.142.2 - 10.1.142.3"
          expect { described_class.new(ip_range_string) }
            .to raise_exception "Invalid input: 3 field/fields separated by '-'"
          ip_range_string = "10.1.142.252/"
          expect { described_class.new(ip_range_string) }
            .to raise_exception ArgumentError,
                                "CIDR address is improperly formatted. Missing netmask after '/' character."
        end
      end

      context "start address is bigger than end address" do
        it "raises an error" do
          ip_range_string = "10.1.142.255 - 10.1.142.1"
          expect { described_class.new(ip_range_string) }
            .to raise_error \
              "IP 10.1.142.255 is bigger than IP 10.1.142.1"
        end
      end

      context "bad subnet mask" do
        it "raises an error" do
          ip_range_string = "10.1.142.0/33"
          expect { described_class.new(ip_range_string) }
            .to raise_error NetAddr::ValidationError,
                            "Netmask, 33, is out of bounds for IPv4."
        end
      end
    end

    describe "#add" do
      subject { described_class.new("10.142.15.11 - 10.142.15.22") }

      let(:ip_range) { described_class.new("10.142.1.0 - 10.142.1.4") }
      it "adds other IpRange correctly" do
        subject.ranges.should have(1).item
        subject.add(ip_range)
        subject.ranges.should have(2).items
        subject.ranges.each do |i|
          i.should be_an_instance_of Range
        end
      end

      context "Not an IpRange type to add" do
        it "raises an error" do
          expect { subject.add("10.142.1.0") }
            .to raise_exception "Unable to parse object that is not IpRange"
        end
      end
    end

    describe "#include?" do
      subject { described_class.new("10.142.15.11 - 10.142.15.22") }

      context "target range is included" do
        it "returns true" do
          ip_range = described_class.new("10.142.15.11")
          subject.include?(ip_range).should be_true

          ip_range = described_class.new("10.142.15.11, 10.142.15.12")
          subject.include?(ip_range).should be_true

          ip_range = described_class.new("10.142.15.19 - 10.142.15.22")
          subject.include?(ip_range).should be_true

          ip_range = described_class.new("10.142.15.19/31")
          subject.include?(ip_range).should be_true
        end
      end

      context "target range is not included" do
        it "returns false" do
          ip_range = described_class.new("10.142.15.09, 10.142.15.12")
          subject.include?(ip_range).should be_false

          ip_range = described_class.new("10.142.15.19 - 10.142.15.25")
          subject.include?(ip_range).should be_false

          ip_range = described_class.new("10.142.15.19/25")
          subject.include?(ip_range).should be_false
        end
      end
    end
  end
end