

package de.unigoettingen.sub.converter;


import io.vertx.core.AbstractVerticle;
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
public class ConvertVerticle extends AbstractVerticle {

    String inpath = "/Users/jpanzer/Documents/projects/test/nlh-importer/tmp/convert_test/";
    String outpath = "/Users/jpanzer/Documents/projects/test/nlh-importer/tmp/convert_test/test";
    String filename = "test.pdf";

    int dpi = 300;

    final static Logger log = Logger.getLogger(ConvertVerticle.class);


    @Override
    public void start() {


        foo();

    }


    public void foo() {


        String from = inpath + filename;
        String to = outpath;


        try {
            boolean result = convertFormat(from, to, "JPG");
            if (result) {
                System.out.println("Image converted successfully.");
            } else {
                System.out.println("Could not convert image.");
            }
        } catch (IOException ex) {
            System.out.println("Error during converting image.");
            ex.printStackTrace();
        }

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