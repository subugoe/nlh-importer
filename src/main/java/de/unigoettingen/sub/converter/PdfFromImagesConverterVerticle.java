

package de.unigoettingen.sub.converter;


import io.vertx.core.AbstractVerticle;
import org.apache.commons.io.FileUtils;
import org.apache.log4j.Logger;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.rendering.ImageType;
import org.apache.pdfbox.rendering.PDFRenderer;
import org.apache.pdfbox.tools.imageio.ImageIOUtil;

import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.util.Map;

/**
 * These are the examples used in the documentation.
 *
 * @author <a href="mailto:pmlopes@gmail.com">Paulo Lopes</a>
 */
public class PdfFromImagesConverterVerticle extends AbstractVerticle {

    final static Logger log = Logger.getLogger(PdfFromImagesConverterVerticle.class);

    int MAX_ATTEMPTS = Integer.valueOf(System.getenv("MAX_ATTEMPTS"));

    String image_in_format = System.getenv("IMAGE_IN_FORMAT");
    String image_out_format = System.getenv("IMAGE_OUT_FORMAT");

    String inpath = System.getenv("IN") + System.getenv("PDF_IN_SUB_PATH");
    String imageoutpath = System.getenv("OUT") + System.getenv("IMAGE_OUT_SUB_PATH");
    String pdfoutpath = System.getenv("OUT") + System.getenv("PDF_OUT_SUB_PATH");
    String originpath = System.getenv("ORIG");
    int pdfdensity = Integer.valueOf(System.getenv("PDFDENSITY"));



    @Override
    public void start() {

        System.out.println("start PdfFromImagesConverterVerticle");

        System.out.println(MAX_ATTEMPTS);
        System.out.println(image_in_format);
        System.out.println(image_out_format);
        System.out.println(inpath);
        System.out.println(imageoutpath);
        System.out.println(pdfoutpath);
        System.out.println(originpath);
        System.out.println(pdfdensity);



        //Read more: http://javarevisited.blogspot.com/2012/08/how-to-get-environment-variables-in.html#ixzz4Qrwv4ltQ

        //foo();

    }


    public void foo() {


        String filepath = inpath + "filename";
        File pdfFile = new File(filepath);
        String destination = "outpath";

        System.out.println("pdfFile: " + pdfFile);
        System.out.println("destination: " + destination);

        //convertPdfToTif(pdfFile, destination, );

    }


    public void convertPdfTo(File pdfFile, String destination, String format) {

        if (!fileExists(pdfFile)) {
            throw new RuntimeException("File not found ! (" + pdfFile.getAbsolutePath() + ")");
        }


        String fileName = "";

        try {

            FileUtils.forceMkdir(new File(destination));

            // load PDF document
            PDDocument document = PDDocument.load(pdfFile, "");


            // create PDF renderer
            PDFRenderer renderer = new PDFRenderer(document);

            // go through each page of PDF, and generate TIF for each PDF page.
            for (int i = 0; i < document.getNumberOfPages(); i++) {
                // Returns the given page as an RGB image with 300 DPI.
                BufferedImage image = renderer.renderImageWithDPI(i, pdfdensity, ImageType.RGB);


                // Assign the file name of TIF
                //String fileName = pdfFileName + "_" + String.format("%06d", i + 1);
                fileName = String.format("%06d", i + 1);


                // Writes a buffered image to a file using the given image format.
                boolean done = ImageIOUtil.writeImage(image, destination + "/" + fileName + ".jpg", pdfdensity);
                log.info("Generating  " + fileName + ".tif to " + destination + " (created=" + done + ")");

                image.flush();

            }

            document.close();


            log.info("PDF to TIF conversion well done for: " + fileName);
        } catch (IOException e) {
            log.error("IOException with destination file: " + destination + "\n");
            e.printStackTrace();
            return;
        } catch (Exception e) {
            log.error("Exception with destination file: " + destination + "\n");
            e.printStackTrace();
            return;
        }
    }


    /**
     *
     */
    private Boolean fileExists(File file) {
        Boolean exists = Boolean.FALSE;
        exists = (file.exists() && (!file.isDirectory()));
        return exists;
    }


}