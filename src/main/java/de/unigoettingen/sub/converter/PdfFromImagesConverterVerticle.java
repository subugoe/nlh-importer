

package de.unigoettingen.sub.converter;


import io.vertx.core.AbstractVerticle;
import io.vertx.core.json.JsonArray;
import io.vertx.core.json.JsonObject;
import io.vertx.redis.RedisClient;
import io.vertx.redis.RedisOptions;
import org.apache.commons.io.FileUtils;
import org.apache.log4j.Logger;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.rendering.ImageType;
import org.apache.pdfbox.rendering.PDFRenderer;
import org.apache.pdfbox.tools.imageio.ImageIOUtil;

import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;


/**
 * These are the examples used in the documentation.
 *
 * @author <a href="mailto:pmlopes@gmail.com">Paulo Lopes</a>
 */
public class PdfFromImagesConverterVerticle extends AbstractVerticle {

    final static Logger log = Logger.getLogger(PdfFromImagesConverterVerticle.class);

    int MAX_ATTEMPTS = Integer.valueOf(System.getenv("MAX_ATTEMPTS"));

    String product = System.getenv("SHORT_PRODUCT");

    String image_in_format = System.getenv("IMAGE_IN_FORMAT");
    String image_out_format = System.getenv("IMAGE_OUT_FORMAT");

    String inpath = System.getenv("IN") + System.getenv("PDF_IN_SUB_PATH");
    String imageoutpath = System.getenv("OUT") + System.getenv("IMAGE_OUT_SUB_PATH");
    //String pdfoutpath = System.getenv("OUT") + System.getenv("PDF_OUT_SUB_PATH");
    String originpath = System.getenv("ORIG");
    int pdfdensity = Integer.valueOf(System.getenv("PDFDENSITY"));

    String redis_host = System.getenv("REDIS_HOST");
    int redis_port = Integer.valueOf(System.getenv("REDIS_EXTERNAL_PORT"));
    int redis_db = Integer.valueOf(System.getenv("REDIS_DB"));


    @Override
    public void start() {

        System.out.println(Thread.currentThread().getName() + " started...");
        
        final RedisClient redis = RedisClient.create(vertx,
                new RedisOptions().setHost(redis_host).setPort(redis_port).setSelect(redis_db));


        // todo find a better way
        for (int i = 0; i < 20; i++) {
            foo(redis);
        }

    }


    public void foo(RedisClient redis) {


        redis.brpop("paths", 30, path -> {
                    if (path.succeeded()) {

                        JsonArray json = path.result();

                        if (json != null) {

                            JsonObject object = new JsonObject(json.getString(1));

                            String from = object.getString("'from'");
                            String name = object.getString("name");
                            String format = object.getString("'format'");

                            String to_dir = imageoutpath + "/" + product + "/" + name + "/";

                            convertPdfTo(new File(from), to_dir, name, format);

                        }

                    }

                }

        );

    }


    public void convertPdfTo(File from, String to_dir, String name, String format) {

        if (!fileExists(from)) {
            throw new RuntimeException("File not found ! (" + from.getAbsolutePath() + ")");
        }


        String fileName = "";

        try {

            FileUtils.forceMkdir(new File(to_dir));

            // load PDF document
            PDDocument document = PDDocument.load(from, "");


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
                boolean done = ImageIOUtil.writeImage(image, to_dir + "/" + fileName + "." + format, pdfdensity);
                log.info("Generating  " + fileName + "." + format + " to " + to_dir + " (created=" + done + ")");

                image.flush();

            }

            document.close();


            log.info("PDF to TIF conversion well done for: " + fileName);
        } catch (IOException e) {
            log.error("IOException with destination file: " + to_dir + "\n");
            e.printStackTrace();
            return;
        } catch (Exception e) {
            log.error("Exception with destination file: " + to_dir + "\n");
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