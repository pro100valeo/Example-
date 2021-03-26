//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// 															!!!!!!!!!!!!!!! ATTENTION !!!!!!!!!!!!!
//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//  Данный класс является исключительно тестовым и не пригоден для текущих проектов
//  Нужен данный пример лишь для демонстрации нашим "младшим" коолегам, принципов работы части нижнего уровня видеорегистраторов

import javax.imageio.stream.FileImageInputStream;
import java.awt.*;
import java.applet.*;
import java.io.*;
import java.nio.file.Files;

class TestLowLvl {

	 public static void main(String[] args) {
        String pathToJpeg = "0.jpg"; 				
        String pathToJp2 = "2.jpg";
        MyImageReader chekFrame = new MyImageReader();
        String answer = chekFrame.getRawImageCode(pathToJp2);
        System.out.println(answer);


        // игры с чтением данных с диска (советую тестировать отдельно)
        // в данном классе больше выводов различных, попробуйте повторить, поигшраться и после этого изучайте документацию на проект
        //MyRead READER = new MyRead();
		//READER.getChek();
    }

    // класс для чтения разных изображений ( напоминаю, что для чтения изображений формата jpeg200 нужно подключить нашу библиотеку с кодеком )
    static class MyImageReader {

    	//---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        // возвращает байт код изображения (c использованием RandomAccesFile) путь до которого указан
    	//---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        public String getRawImageCode(String path) {
            StringBuffer buff = new StringBuffer("");
            try (FileInputStream image = new FileInputStream(path)) {
                System.out.printf("File size %d bytes \n", image.available());
                int a = image.read();
                while(a != -1) {
                    buff.append(a + " ");
                    a = image.read();
                }
            } catch (IOException e) {
                System.err.println("Oops " + e.getStackTrace());
                buff.substring(0);
                buff.append("Не вышло)");
            }
            return buff.toString();
        }


    	//---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        // возвращает байт код изображения (c использованием прямого доступа к файлу) путь до которого указан
        // фактически, в проекте данное преобразование выглядит по другому, но в качетсве примера сойдет
    	//---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        public String getImageCode(String path) {
            try {
            	File image = new File(path);
				byte[] fileContent = Files.readAllBytes(image.toPath())
            }

            return fileContent;
        }

    	//---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        // создаем изображение на основе байт кода
        // в файле с полной информацией о проекте все подробно расписано, поэтому сильно не увлекайтесь данным примером
    	//---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        public void createJpeg (byte[] byteArrayIn) {
        	using (MemoryStream memstr = new MemoryStream(byteArrayIn)) {
        		Image img = Image.FromStream(memstr);
        		return img;
    		}
        }
    }

    // клас читающий сырые данные с диска
    public static class MyRead{
		 public void getChek() {
			 RandomAccessFile raf = null;
				int [] block = new int [2048];

		    	try {
		            raf = new RandomAccessFile("\\\\\\\\.\\\\D:","r");      // "r" - файл открыт только для чтения
		        	raf.seek(0); 											// задается смещение по символам в случае txt файлов, например seek(100) - обратится к 101 символу документа

		        	for (int i : block) {
		        		block[i] = raf.read();
		        	}

		    	} catch(IOException ioe) {
		    		System.out.println("File not found or access denied. Cause: " + ioe.getMessage());
		        	return;
		    	} finally {
		        	try {
		        	    if (raf != null) raf.close();
		        	    System.out.println("Exiting...");
		        	} catch (IOException ioe) {
		        	    System.out.println("That was bad.");
		        	}
		    	}
		    	System.out.println("READ DATA");
		    	for (int i = 0; i < 2048; i++) {
		    		System.out.println(block[i]);
				}
		        System.out.println(block[0]);
		        System.out.println(Integer.toBinaryString(block[0]));
		    	System.out.println("End of session");
		 }
	 }
} 