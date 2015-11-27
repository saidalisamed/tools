IOS Push Notification Steps
===========================
Simple IOS APNs Test project with SNS integration.

Create IOS Project
-------------------

    
Publishing Notification using AWS SNS
-------------------------------------
Advantage of using SNS is scalability which is required when publishing tens of millions of notifications in a very short time and abstracts interaction with different push services behind a unified API.

1. Add a new platform application in SNS console -> Applications.
2. Enter **APNsTest** for the name.
3. Select **IOS Development** from the **Push Notification Platform** drop down menu.
4. TODO
5. Click **Create Platform Application** button.
6. Click on the new application ARN to enter.
7. Click **Create Platform Endpoint** button.
8. Paste your **Device Token** in the **Device token** field.
9. Enter optional data in **User Data** field.
10. Click **Add Endpoint** button.
11. Select the newly added endpoint from the list.
12. Click **Publish to endpoint** button.
13. Select **JSON** for **Message format**.
14. Enter the following in the **Message** box and click **Publish message** button.

    ```json
    {
    "GCM": "{ \"data\": { \"message\": \"Test message from SNS console.\", \"title\": \"GcmTest\" } }"
    }
    ```        
    