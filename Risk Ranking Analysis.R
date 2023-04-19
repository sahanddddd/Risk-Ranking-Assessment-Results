# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
### Code to plot the results of the ACDC Risk Ranking Survey  ######
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# 01/09/2022


# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
### Load the libraries ######
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
library( dplyr )
library( magrittr )
library( ggplot2 )
library( EnvStats )
library( here )
library( readxl )
library( tidyverse )
require("ggrepel")

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
### Load the data from the local directory ######
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

df_survey <- read_excel(here("data/ACDC_Data_All_Transformed_220518.xlsx"), sheet = "Data_Transformed", col_names = TRUE, col_types = NULL, na = "", skip = 0)
df_survey <- df_survey %>% # Select the relevant columns of the data and pivot longer
  select(-start, -end, -Name, -Email, -Organisation, -Occupation, -`Submission Time`, -Average ) %>% 
  pivot_longer(cols = 3:21, names_to = "criterion", values_to = "value") #%>%


# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
### Main loop to compute/aggregate the survey values into 4 values per disease per participant ######
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

df_summary_disease <- NULL # Initiate the final data frame
all_diseases <- unique( df_survey$Disease ) # List of all diseases
all_IDs <- unique( df_survey$Unique_ID ) # List of all participants IDs in the survey
# Loop over all diseases 
for ( disease_i in all_diseases ){
  print(paste("Completed disease:", disease_i))
  
  for ( id in all_IDs ){ # Loop over all survey participants
    
    # Select only survey answers for a given disease and participant
    df_replies_disease_i <- df_survey %>% filter(Disease == disease_i, Unique_ID == id)
    
    # Compute A. Risk trajectory mean value; mean value of answers C1 and C2
    df_replies_disease_i %>% 
      filter( criterion %in% c("risk_trajectory_c1", "risk_trajectory_c2")) %>% 
      pull(value) %>% mean(na.rm=T)-> A_i
    
    # Compute B. Epidemic potential mean value; mean value of answers C3, C4, and C5
    df_replies_disease_i %>% 
      filter( criterion %in% c("epidemic_potential_c3", "epidemic_potential_c4", "epidemic_potential_c5")) %>% 
      pull(value) %>% mean(na.rm=T)-> B_i
    
    # Compute C. Disease severity mean value; mean value of answers C7, C8, C9, and C10
    df_replies_disease_i %>% 
      filter( criterion %in% c("disease_severity_c6", "disease_severity_c7", "disease_severity_c8", "disease_severity_c9")) %>% 
      pull(value) %>% mean(na.rm=T)-> C_i
    
    
    
    # Define and compute values for questions in D. Preparedness and countermeasures
    # Value for question C10
    df_replies_disease_i %>% 
      filter( criterion =="preparedness_c10") %>% 
      pull(value) -> score_c10
    
    # Compute geometric mean of Vaccine questions C12a, C12b, and C12c
    df_replies_disease_i %>% 
      filter( criterion %in% c("preparedness_c11a", "preparedness_c11b", "preparedness_c11c")) %>% 
      pull(value) %>% geoMean(na.rm=T) -> score_c11
    
    # Compute geometric mean of Pharmaceutical countermeasures questions C13a, C13b, and C13c
    df_replies_disease_i %>% 
      filter( criterion %in% c("preparedness_c12a", "preparedness_c12b", "preparedness_c12c")) %>% 
      pull(value) %>% geoMean(na.rm=T) -> score_c12
    
    # Compute geometric mean of Public health and social measures questions C14a, C14b, and C14c
    df_replies_disease_i %>% 
      filter( criterion %in% c("preparedness_c13a", "preparedness_c13b", "preparedness_c13c")) %>% 
      pull(value) %>% geoMean(na.rm=T) -> score_c13
    
    # Compute D. Preparedness and countermeasures mean value; mean value of answers C11, C12, C13, and C14
    D_i <- mean( c( score_c10, score_c11, score_c12, score_c13 ), na.rm=T  )
    
    
    # Summarize the averaged values for the four groups of questions (A, B, C, and D)
    df_summary_disease %<>% bind_rows( tibble( disease = disease_i,
                                               Unique_ID = id,
                                               A_risk_trajectory=A_i, 
                                               B_epidemic_potential=B_i,
                                               C_severity=C_i,
                                               D_preparedness=D_i) )
    
    
  }
}



# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
### Summarize the results ######
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# Compute mean and sd of each groups type (A, B, C, and D) over all survey participants
df_results <- df_summary_disease %>% 
  group_by(disease) %>% # Group by disease so all operations below are done per disease
  summarize(A_mean = mean(A_risk_trajectory, na.rm=T),
            A_sd = sd(A_risk_trajectory, na.rm=T),
            B_mean = mean(B_epidemic_potential, na.rm=T),
            B_sd = sd(B_epidemic_potential, na.rm=T),
            C_mean = mean(C_severity, na.rm=T),
            C_sd = sd(C_severity, na.rm=T),
            D_mean = mean(D_preparedness, na.rm=T),
            D_sd = sd(D_preparedness, na.rm=T)) %>%
  ungroup() %>%
  mutate(AB_mean = ( A_mean + B_mean  )/2, # Compute average value of A and B
         AB_sd = sqrt(A_sd^2 + B_sd^2))



# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
### Plot the results ######
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# A figure with errorbars
df_results %>% 
  ggplot(aes(x=C_mean, y=AB_mean) ) +
  geom_point(size=2*(df_results$D_mean-1)) +
  geom_errorbar(aes(ymin = AB_mean-AB_sd,ymax = AB_mean+AB_sd), alpha=0.15) + 
  geom_errorbarh(aes(xmin = C_mean-C_sd,xmax = C_mean+C_sd), alpha=0.15) +
  labs(x="Outbreak impact", y="Risk trajectory and epidemic potential") +
  geom_text_repel(aes(label = disease), size = 3.) +
  ylim(c(1,5)) +
  xlim(c(1,5)) +
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())


# Plot results without errorbars - a clearer look of the details
df_results %>% 
  ggplot(aes(x=C_mean, y=AB_mean) ) +
  geom_point(size=2*(df_results$D_mean-1)) +
  labs(x="Outbreak impact", y="Risk trajectory and epidemic potential") +
  geom_text_repel(aes(label = disease), size = 3.) +
  ylim(c(2,4)) +
  xlim(c(2,4)) +
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())

















