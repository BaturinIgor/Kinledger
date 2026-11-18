import SwiftUI

enum ReportPDF {
    /// Renders the same `ReportPage` the screen shows into a one-page PDF, light theme.
    @MainActor
    static func render(report: MonthReport, includeNotes: Bool) throws -> URL {
        let page = ReportPage(report: report, includeNotes: includeNotes)
            .padding(32)
            .frame(width: 612)
            .background(Color.white)
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: page)
        renderer.proposedSize = ProposedViewSize(width: 612, height: nil)

        let name = "Kinledger report \(report.month.formatted(.dateTime.year().month(.twoDigits))).pdf"
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        var failure: Error?
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else {
                failure = CocoaError(.fileWriteUnknown)
                return
            }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
        }
        if let failure { throw failure }
        return url
    }
}
