package tw.edu.cgu.ai.painrating;

import androidx.appcompat.app.AppCompatActivity;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.RectF;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.view.MotionEvent;
import android.view.View;
import android.widget.ImageView;
import android.widget.Toast;
import android.content.Intent;

import java.io.OutputStream;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.List;

public class PainActivity extends AppCompatActivity {

    // These constants represent the image's original pixel dimensions (width, height)
    private static final float ORIG_IMG_WIDTH = 2346f;
    private static final float ORIG_IMG_HEIGHT = 840f;

    // The coordinate bounds of each face in the original image
    private final List<RectF> faceBounds = new ArrayList<>();

    // Declare ImageView as a member (class-level field) to avoid the “needs to be declared final” issue
    private ImageView imgPainScale;

    private String mServerURL;
    private Integer mPortNumber;

    Socket SocketToServer;
    int gfaceIndex;

    protected void RetrieveSharedPreferences(){
        SharedPreferences sharedPref = getSharedPreferences("PainRating_Preference", Context.MODE_PRIVATE);
        String ServerURL = sharedPref.getString("ServerURL", "");
        if (!ServerURL.isEmpty()) {
            mServerURL = ServerURL;
        }

        String PortNumber = sharedPref.getString("PortNumber", "");
        if (!PortNumber.isEmpty()) {
            mPortNumber = Integer.parseInt(PortNumber);
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_pain);
        // ↑ Add an ImageView (id=@+id/imgPainScale) to this layout to display the full rating scale image

        // 1) Set the face regions (assuming six faces for 0, 2, 4, 6, 8, and 10)
        //   The example coordinates below are (left, top, right, bottom); adjust them for the actual image
        faceBounds.add(new RectF( 0, 100, 391, 700));  // Score 0
        faceBounds.add(new RectF(391, 100, 782, 700));  // Score 2
        faceBounds.add(new RectF(782, 100, 1173, 700));  // Score 4
        faceBounds.add(new RectF(1173, 100, 1564, 700));  // Score 6
        faceBounds.add(new RectF(1564, 100, 1955, 700));  // Score 8
        faceBounds.add(new RectF(1955, 100, 2346, 700));  // Score 10

        // 2) Connect the ImageView
        imgPainScale = findViewById(R.id.imgPainScale);

        // 3) Set the touch listener (demonstrating ACTION_DOWN only)
        imgPainScale.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                if (event.getAction() == MotionEvent.ACTION_DOWN) {
                    // (A) Get the user's tapped x and y coordinates relative to the top-left corner of imgPainScale
                    float clickX = event.getX();
                    float clickY = event.getY();

                    // (B) Get the actual displayed width and height of the ImageView
                    float displayedWidth = imgPainScale.getWidth();
                    float displayedHeight = imgPainScale.getHeight();

                    // (C) Convert the tap position back to coordinates in the original image
                    float ratioX = clickX / displayedWidth;
                    float ratioY = clickY / displayedHeight;
                    float originalX = ratioX * ORIG_IMG_WIDTH;
                    float originalY = ratioY * ORIG_IMG_HEIGHT;

                    // (D) Determine which face region was tapped
                    int faceIndex = getFaceIndex(originalX, originalY);
                    if (faceIndex == -1) {
                        Toast.makeText(PainActivity.this,
                                "未點中任何臉", Toast.LENGTH_SHORT).show();
                    } else {
                        // Display the score
                        showFaceToast(faceIndex);
                        gfaceIndex = faceIndex;
                    }

                    //There are two types of touch events: ACTION_DOWN and ACTION_UP.
                    //Create a socket, send a message to the server and close the socket.
                    HandlerThread thread = new HandlerThread("SocketProcess");
                    thread.start();
                    Handler handler = new Handler(thread.getLooper());
                    handler.post(new Runnable() {
                        @Override
                        public void run() {
                            try {
                                RetrieveSharedPreferences();
                                SocketToServer = new Socket(mServerURL, mPortNumber);
                                if (SocketToServer.isConnected()) {
                                    OutputStream os = SocketToServer.getOutputStream();
                                    os.write("Begin:".getBytes());
                                    Long message_length = (long) (4);   //value
                                    ByteBuffer buffer = ByteBuffer.allocate(8);
                                    buffer.order(ByteOrder.LITTLE_ENDIAN); // Ubuntu byte order
                                    buffer.putLong(message_length);
                                    byte[] byteArray = buffer.array();
                                    os.write(byteArray);

                                    ByteBuffer buffer2 = ByteBuffer.allocate(4);
                                    buffer2.order(ByteOrder.LITTLE_ENDIAN); // Ubuntu byte order
                                    buffer2.putInt(gfaceIndex);
                                    byte[] byteArray2 = buffer2.array();
                                    os.write(byteArray2);

//                                os.write(gfaceIndex);   //Here is the bug, only 1 byte is sent. Need to send 4 bytes. Maybe there is an implicit convertion.
                                    os.write("EndOfAFrame".getBytes());
                                } else {
                                }
                                SocketToServer.close();
                            } catch (Exception e) {
                                e.printStackTrace();
                            }
                        }
                    });




                }


                return true; // Returning true means the event was consumed
            }
        });


    }

    /**
     * 尋找 (x, y) 是否落在 faceBounds 裡任何一個 RectF
     * @return 回傳臉的索引(0~5)，或 -1 代表找不到
     */
    private int getFaceIndex(float x, float y) {
        for (int i = 0; i < faceBounds.size(); i++) {
            RectF rect = faceBounds.get(i);
            if (rect.contains(x, y)) {
                return i;
            }
        }
        return -1;
    }

    /**
     * 依臉的索引顯示對應分數的 Toast (示範)
     */
    private void showFaceToast(int index) {
        switch (index) {
            case 0:
                // Select score 0
                startFaceResultActivity(0);
                break;
            case 1:
                startFaceResultActivity(2);
                break;
            case 2:
                startFaceResultActivity(4);
                break;
            case 3:
                startFaceResultActivity(6);
                break;
            case 4:
                startFaceResultActivity(8);
                break;
            case 5:
                startFaceResultActivity(10);
                break;
        }
    }
    private void startFaceResultActivity(int score) {
        // Pass the score to FaceResultActivity using an Intent
        Intent intent = new Intent(PainActivity.this, FaceResultActivity.class);
        intent.putExtra("score", score);
        startActivity(intent);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        try {
            SocketToServer.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
