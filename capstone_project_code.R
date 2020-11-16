library(tidyverse)
library(rvest)
library(rio)
library(here)
library(httr)
library(RSelenium)
library(seleniumPipes)
library(wdman)

# Download Docker Desktop from https://www.docker.com/get-started for your OS

# To download the docker image for Selenium in Chrome or Firefox.
system("docker run --name chrome_server  --detach --publish 4445:4444 --publish 5901:5900 selenium/standalone-chrome-debug")
system("docker run --name firefox_server  --detach --publish 4445:4444 --publish 5901:5900 selenium/standalone-firefox-debug")

# Open Docker, go to "Images", click "Run" and select "Optional Setting".
# Set the port to 4445 and add a second port with "+" setting it to 5899. Run it.
# Now you have created a new container image of Selenium. 
# This is necessary because the initial ones don't work. 

# Afterwards, you will launch your browser inside this container image. 
# Since it does not have a UI and you will want to
# see what your code is doing step by steop you need another program that is able
# to see inside the container image. Go to https://www.realvnc.com/en/connect/download/viewer/macos/, 
# and download and install VNC Viewer for your OS. 
# Launch VNC Viewer and connect to 127.0.0.1:5899, the password is "secret" by default.

# Check out these pages or directly go ahead with the code below.
# http://joshuamccrain.com/tutorials/web_scraping_R_selenium.html
# https://www.rdocumentation.org/packages/seleniumPipes/versions/0.3.7/topics/findElement

# The companies whose MSCI ESG Rating I would like to automatically retrieve
comp_empl <- import("data/data-hA9UT.csv")
comp_empl <- comp_empl$`Largest companies by employment`[1:8]

# Unfortunately the more convenient seleniumPipes has a bug, but it would work like this:
remDr <- remoteDr(browserName = "chrome", port=4445L)
remDr %>% 
  go("http://www.google.com/ncr") %>% 
  findElement(using = "name", value = "q")

# Instead we have to use the RSelenium standard notation.
rD <- rsDriver(browser="firefox", port=4445L, verbose=F)
remDr <- rD[["client"]]

comp_stock_code <- vector(mode = "character", length = length(comp_empl))

for (i in 1:length(comp_empl)) {
  remDr$open()
  remDr$navigate("http://www.google.com")
  Sys.sleep(2)
  remDr$findElement(using = "name", "q")$sendKeysToElement(list(comp_empl[i], key = "enter"))
  Sys.sleep(2)
  html <- remDr$getPageSource()[[1]]
  signal <- read_html(html)
  comp_stock_code[i] <- signal %>% 
                          html_nodes(".PZPZlf > .kno-fv > .fl") %>% 
                          html_text()
  Sys.sleep(2)
}

comp_stock_code[6] <- "RHHBY"

save(comp_stock_code, file = here::here("data/comp_stock_code.RData"))

comp_esg_scores <- vector(mode = "character", length = length(comp_empl))

for (i in 1:length(comp_esg_scores)) {
  remDr$navigate("https://www.msci.com/esg-ratings")
  Sys.sleep(2)
  cookie <- remDr$findElement(using = "class", value = "gdpr-allow-cookies")
  cookie$clickElement()
  Sys.sleep(2)
  remDr$findElement(using = "css", value = "#_esgratingsprofile_keywords")$sendKeysToElement(list(comp_stock_code[i]))
  Sys.sleep(2)
  search <- remDr$findElement(using = "css", value = "#ui-id-1")
  search$clickElement()
  Sys.sleep(2)
  html1 <- remDr$findElement(using = "xpath", value = "/html/body/div[1]/section/div[1]/div/div/div/div[3]/section/div/div[2]/div/div/div[2]/div/div[2]/div[3]/div")$getElementText()[[1]]
  html1 <- html1 %>% 
    strsplit("\\\\|[^[:print:]]", fixed = FALSE)
  comp_esg_scores[i] <- html1[[1]][5]
  Sys.sleep(2)
}

companies <- data.frame(name = comp_empl, 
                        stock_code = comp_stock_code,
                        esg_score = comp_esg_scores)




