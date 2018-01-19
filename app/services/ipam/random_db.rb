module IPAM
  # Internal DB IPAM returning all IPs in random order to minimize race conditions
  class RandomDb < Base
    def generator
      @generator ||= Random.new(mac ? mac.delete(':').to_i(16) : Random.new_seed)
    end

    def random_ip
      IPAddr.new(generator.rand(subnet_range.first.to_i..subnet_range.last.to_i), subnet.family)
    end

    # Safety check not to spend much CPU time when there are no many free IPs left. This gives up
    # in about a second on Ryzen 1700 running with Ruby 2.4.
    MAX_ITERATIONS = 100_000
    def suggest_ip
      iterations = 0
      loop do
        # next random IP from the sequence generated by MAC seed
        candidate = random_ip
        iterations += 1
        break if iterations >= MAX_ITERATIONS
        # try to match it
        ip = candidate.to_s
        if !excluded_ips.include?(ip) && !subnet.known_ips.include?(ip)
          logger.debug("Found #{ip} in #{iterations} iterations")
          return ip
        end
      end
      logger.debug("Not suggesting IP Address for #{subnet} as no free IP found in reasonable time (#{iterations} iterations)")
      errors.add(:subnet, _('no random free IP could be found in our DB, enlarge subnet range'))
      nil
    end
  end
end