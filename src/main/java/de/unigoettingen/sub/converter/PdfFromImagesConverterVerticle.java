

package de.unigoettingen.sub.converter;


import io.vertx.core.AbstractVerticle;
import io.vertx.core.json.JsonArray;
import io.vertx.core.json.JsonObject;
import io.vertx.redis.RedisClient;
import io.vertx.redis.RedisOptions;
import org.apache.log4j.Logger;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;

/**
 * These are the examples used in the documentation.
 *
 * @author <a href="mailto:pmlopes@gmail.com">Paulo Lopes</a>
 */
public class PdfFromImagesConverterVerticle extends AbstractVerticle {

    //String outpath = "/outpath/";
    String outpath = "/Users/jpanzer/Documents/projects/test/nlh-importer/out/";

    int dpi = 300;

    final static Logger log = Logger.getLogger(PdfFromImagesConverterVerticle.class);


    @Override
    public void start() {


        System.out.println(Thread.currentThread().getName() + " started...");
        String host = "127.0.0.1";
        int port = 8442;

        final RedisClient redis = RedisClient.create(vertx,
                new RedisOptions().setHost(host).setPort(port));


        // todo find a better way
        for (int i = 0; i < 20; i++) {
            foo(redis);
        }

    }


    public void foo(RedisClient redis) {

        redis.brpop("processPdfFromImageURI", 30, path -> {
                    if (path.succeeded()) {

                        JsonArray json = path.result();

                        if (json != null) {

                            JsonObject object = new JsonObject(json.getString(1));


                            String image_uri = object.getString("image_uri");
                            String mets_path = object.getString("path");

                            System.out.println("PdfFromImagesConverterVerticle: " + image_uri);
                            System.out.println("PdfFromImagesConverterVerticle: " + mets_path);

                            //String to = object.getString("to");
                            //String fullpath = object.getString("path");

                            //System.out.println("source: " + from);
                            //System.out.println("destination: " + to);


//                            try {
//                                boolean result = convertFormat(from, to, "JPG");
//                                if (result) {
//                                    System.out.println("Image converted successfully.");
//                                } else {
//                                    System.out.println("Could not convert image.");
//                                }
//                            } catch (IOException ex) {
//                                System.out.println("Error during converting image.");
//                                ex.printStackTrace();
//                            }

                        }

                    }

                }

        );

    }

    public static boolean convertFormat(String inputImagePath,
                                        String outputImagePath, String formatName) throws IOException {
        FileInputStream inputStream = new FileInputStream(inputImagePath);
        FileOutputStream outputStream = new FileOutputStream(outputImagePath);

        // reads input image from file
        BufferedImage inputImage = ImageIO.read(inputStream);

        // writes to the output image in specified format
        boolean result = ImageIO.write(inputImage, formatName, outputStream);

        // needs to close the streams
        outputStream.close();
        inputStream.close();

        return result;
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