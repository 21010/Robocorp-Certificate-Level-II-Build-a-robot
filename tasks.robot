*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.HTTP
Library             RPA.Tables
Library             RPA.Browser.Selenium    auto_close=False
Library             RPA.PDF
Library             RPA.FileSystem
Library             RPA.Archive
Library             RPA.Dialogs
Library             RPA.Robocorp.Vault


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Clean environment    True
    Open the robot order website
    ${orders}=    Get orders
    FOR    ${order}    IN    @{orders}
        Close the annoying modal
        Fill the form    ${order}
        Preview the robot
        Submit the order
        ${pdf}=    Store the receipt as a PDF file    ${order}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${order}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Go to order another robot
    END
    Create a ZIP file of the receipts
    Clean environment    False
    [Teardown]    Close Window


*** Keywords ***
Clean environment
    [Arguments]    ${init}
    # set variables for paths
    ${receipts_folder_path}=    Set Variable    ${OUTPUT_DIR}${/}receipts
    ${previews_folder_path}=    Set Variable    ${OUTPUT_DIR}${/}previews

    # remove old orders.csv file
    Remove File    ${OUTPUT_DIR}${/}orders.csv

    # remove old orders.zip file
    IF    ${init} == True    Remove File    ${OUTPUT_DIR}${/}orders.zip

    # remove old receipts and previews folders if exist
    ${folder_exists}=    Does Directory Exist    ${receipts_folder_path}
    IF    ${folder_exists} == True
        Remove Directory    ${receipts_folder_path}    True
    END

    ${folder_exists}=    Does Directory Exist    ${previews_folder_path}
    IF    ${folder_exists} == True
        Remove Directory    ${previews_folder_path}    True
    END

    IF    ${init} == True
        Create Directory    ${OUTPUT_DIR}${/}receipts
        Create Directory    ${OUTPUT_DIR}${/}previews
    END

Ask for the Url to orders.csv file
    Add heading    Please provide the URL to orders.csv file.
    Add text input
    ...    name=url
    ...    label=Url
    ...    placeholder=https://robotsparebinindustries.com/orders.csv
    ${response}=    Run dialog
    RETURN    ${response.url}

Get orders
    TRY
        ${url}=    Ask for the Url to orders.csv file
        Download    ${url}    ${OUTPUT_DIR}${/}orders.csv
    EXCEPT
        Add icon    Failure
        Add heading    Provided URL is invalid.
        Add text    Cannot download csv file from ${url}.
        Add text    Please re-run the bot and provide valid Url.
        Run dialog    title=Failure
        Fail    Incorrect Url provided: ${url}. Cannot find the csv file.
    END

    ${orders}=    Read table from CSV    ${OUTPUT_DIR}${/}orders.csv    header=True    delimiters=","
    RETURN    ${orders}

Open the robot order website
    ${urls}=    Get Secret    urls
    Open Available Browser
    ...    ${urls}[store]
    ...    maximized=True

Close the annoying modal
    Wait And Click Button    //*[@id="root"]/div/div[2]/div/div/div/div/div/button[1]

Fill the form
    [Arguments]    ${order}
    Select From List By Value    id:head    ${order}[Head]
    Select Radio Button    body    ${order}[Body]
    Input Text    css:form input:nth-child(3)    ${order}[Legs]
    Input Text    id:address    ${order}[Address]

Preview the robot
    Click Button    id:preview

Submit the order
    Wait And Click Button    id:order
    FOR    ${counter}    IN RANGE    0    100
        ${error}=    Is Element Visible    //*[@id="root"]/div/div[1]/div/div[1]/div
        IF    ${error} == True    Click Element If Visible    id:order
        IF    ${error} == False    BREAK
    END

Store the receipt as a PDF file
    [Arguments]    ${order_number}
    ${path}=    Set Variable    ${OUTPUT_DIR}${/}receipts${/}${order_number}.pdf
    Wait Until Page Contains Element    id:receipt
    ${receipt_html}=    Get Element Attribute    id:receipt    outerHTML
    Html To Pdf    ${receipt_html}    ${path}
    RETURN    ${path}

Take a screenshot of the robot
    [Arguments]    ${order_number}
    ${path}=    Set Variable    ${OUTPUT_DIR}${/}previews${/}${order_number}.png
    Screenshot    id:robot-preview-image    ${path}
    RETURN    ${path}

Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${screenshot}    ${pdf}
    Add Watermark Image To Pdf
    ...    image_path=${screenshot}
    ...    source_path=${pdf}
    ...    output_path=${pdf}

Go to order another robot
    Wait and Click Button    id:order-another

Create a ZIP file of the receipts
    Archive Folder With Zip    ${OUTPUT_DIR}${/}receipts    ${OUTPUT_DIR}${/}orders.zip
