require 'pdfkit'
require File.dirname(__FILE__) + '/helper.rb'

module Jekyll
  module PDF
    class Document < Jekyll::Page
      include Helper

      def initialize(site, base, page)
        #site.config['baseurl'] = ''
        @site = site
        @base = base
        @dir = File.dirname(page.url)
        @name = File.basename(page.url, File.extname(page.url)) + '.pdf'
        @settings = site.config.key?('pdf') ? site.config['pdf'].clone : {}
        @partials = %w[cover header_html footer_html]

        process(@name)
        @page = page
        self.data = page.data.clone

        # Set layout to the PDF layout
        data['layout'] = layout

        # Get PDF settings from the layouts
        Jekyll::Utils.deep_merge_hashes!(@settings, get_config(data))

        PDFKit.configure do |config|
          config.verbose = site.config['verbose']
        end

        # Set pdf_url variable in the source page (for linking to the PDF version)
        page.data['pdf_url'] = url

        # Set html_url variable in the source page (for linking to the HTML version)
        data['html_url'] = page.url

        # create the partial objects
        @partials.each do |partial|
          @settings[partial] = Jekyll::PDF::Partial.new(self, @settings[partial]) unless @settings[partial].nil?
        end
      end

      # Recursively merge settings from the page, layout, site config & jekyll-pdf defaults
      def get_config(data)
        settings = data['pdf'].is_a?(Hash) ? data['pdf'] : {}
        # Safely resolve the parent layout's front matter
        if data['layout'].is_a?(String)
          layout_doc = @site.layouts[data['layout']]
          layout = layout_doc && layout_doc.data ? layout_doc.data.clone : nil
        else
          layout = nil
        end

        # No parent layout found - return settings hash
        return settings if layout.nil?

        # Merge settings with parent layout settings
        layout['pdf'] ||= {}
        Jekyll::Utils.deep_merge_hashes!(layout['pdf'], settings)

        get_config(layout)
      end

      # Write the PDF file
      # todo: remove pdfkit dependency
      def write(dest_prefix, _dest_suffix = nil)
        if output.nil?
          previous_pdf_mode = @site.config['jekyll_pdf_mode']
          @site.config['jekyll_pdf_mode'] = true
          begin
            @page.render(@site.layouts, @site.site_payload)
          ensure
            @site.config['jekyll_pdf_mode'] = previous_pdf_mode
          end
        end
        # Avoid sharing the same String object as the page HTML to prevent accidental mutation
        self.output = @page.output.dup

        path = File.join(dest_prefix, CGI.unescape(url))
        dest = File.dirname(path)

        # Create directory
        FileUtils.mkdir_p(dest) unless File.exist?(dest)

        # write partials
        @partials.each do |partial|
          @settings[partial].write unless @settings[partial].nil?
        end

        # Debugging - create html version of PDF
        if @settings['debug']
          File.open("#{path}.html", 'w') { |f| f.write(@page.output) }
        end
        @settings.delete('debug')
        @settings.delete('layout')

        # Build PDF file
        # Ensure wkhtmltopdf can read local files
        @settings[:enable_local_file_access] = true unless @settings.key?(:enable_local_file_access)
        # Reduce flakiness: disable JS and ignore missing resources
        @settings[:disable_javascript] = true unless @settings.key?(:disable_javascript)
        @settings[:load_error_handling] = 'ignore' unless @settings.key?(:load_error_handling)
        @settings[:disable_external_links] = true unless @settings.key?(:disable_external_links)
        # Rewrite root-relative links and inject a base href so relative URLs resolve
        html_for_pdf = rewrite_relative_paths(@page.output)
        base_href = "file://#{@site.dest}/"
        if html_for_pdf =~ /<head[^>]*>/i
          html_for_pdf.sub!(/<head([^>]*)>/i, "<head\\1><base href=\"#{base_href}\">")
        else
          html_for_pdf = "<base href=\"#{base_href}\">" + html_for_pdf
        end

        # Write a temporary HTML file so wkhtmltopdf resolves relative URLs correctly
        tmp_html = File.join(dest, File.basename(path) + ".wkhtml.html")
        File.open(tmp_html, 'w') { |f| f.write(html_for_pdf) }

        kit = PDFKit.new("file://#{tmp_html}", @settings)
        file = kit.to_file(path)
      end

      def layout
        # Candidate from page/front matter or site pdf settings
        candidate = data['pdf_layout'] || @settings['layout']

        # Prefer explicit candidate if its file exists
        if candidate && File.exist?(File.join('_layouts', "#{candidate}.html"))
          return candidate
        end

        # Try <page_layout>_pdf.html next
        if data['layout'].is_a?(String)
          pdf_variant = "#{data['layout']}_pdf"
          if File.exist?(File.join('_layouts', "#{pdf_variant}.html"))
            return pdf_variant
          end
        end

        # Try generic pdf.html
        return 'pdf' if File.exist?(File.join('_layouts', 'pdf.html'))

        # Fallback to the page layout or default
        data['layout'] || 'default'
      end
    end
  end
end
