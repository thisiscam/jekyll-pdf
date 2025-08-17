module Jekyll
  module PDF
    class Generator < Jekyll::Generator
      safe true
      priority :low

      def generate(site)
        items = [site.pages, site.documents].flatten
        items.each do |item|
          next unless item.data.is_a?(Hash) && item.data.key?('pdf')
          site.pages << Document.new(site, site.dest, item)
        end
      end
    end
  end
end
