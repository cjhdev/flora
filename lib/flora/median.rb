module Flora

  module Median
  
    def calculate_median(values)
      sorted = values.sort!
      len = sorted.size
      (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
    end
  
  end

end
