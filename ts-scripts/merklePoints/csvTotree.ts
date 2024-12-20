import fs from 'fs/promises';
import Papa from 'papaparse';
import path from 'path';
import { Address, isAddress, parseEther } from 'viem';

const __dirname = path.dirname(new URL(import.meta.url).pathname);

const VOTING_THRESHOLD = 50;

async function convertCSVFileToJSON(filename: string) {
  try {
    // Read the file
    const fileContent = await fs.readFile(filename, 'utf-8');

    // Parse the CSV
    return new Promise((resolve, reject) => {
      Papa.parse(fileContent, {
        header: true,
        dynamicTyping: false,
        skipEmptyLines: true,
        complete: (results) => {
          resolve(results.data);
        },
        // transform: (value) => {
        //   // If the value looks like a number with commas
        //   if (/^-?\d{1,3}(,\d{3})*(\.\d+)?$/.test(value)) {
        //     // Remove commas and convert to number
        //     return Number(value.replace(/,/g, ''));
        //   }
        //   return value;
        // },
        error: (error: any) => {
          reject(error);
        },
      });
    });
  } catch (error) {
    throw new Error(`Failed to read or parse file: ${error}`);
  }
}

const filterByVotingThreshold = (
  data: {
    address: Address;
    amount: bigint;
  }[]
) => {
  return data.filter(
    (item) => item.amount >= parseEther(VOTING_THRESHOLD.toString())
  );
};

const validateAndConvert = async (data: any) => {
  try {
    if (!Array.isArray(data)) throw new Error('Data is not an array');

    return data.map((item: any) => {
      if (
        !item.HolderAddress ||
        !item.Balance ||
        typeof item.HolderAddress !== 'string' ||
        typeof item.Balance !== 'string'
      ) {
        throw new Error(
          `Invalid data format: ${item.HolderAddress}, ${item.Balance}
          
          typeof item.HolderAddress: ${typeof item.HolderAddress}
          typeof item.Balance: ${typeof item.Balance}   
          `
        );
      }

      if (!isAddress(item.HolderAddress)) {
        throw new Error(`Invalid address: ${item.HolderAddress}`);
      }

      return {
        address: item.HolderAddress as Address,
        amount: parseEther(item.Balance.replace(/,/g, '')),
      };
    });
  } catch (error: any) {
    throw new Error(`Failed to validate and convert data: ${error}`);
  }
};

// Usage:
async function main() {
  try {
    const jsonData = await convertCSVFileToJSON(
      path.join(__dirname, './csv/GTCTokenHolders-Dec_16_2024.csv')
    );

    const cleanData = await validateAndConvert(jsonData);
    const filteredData = filterByVotingThreshold(cleanData);

    console.log('****FINAL OUTPUT******');
    console.log(filteredData);

    console.log('****First 3 entries******');
    console.log(filteredData.slice(0, 3));

    console.log('****Last 3 entries******');
    console.log(filteredData.slice(-3));

    console.log('****Last Below Threshold******');
    console.log(cleanData[filteredData.length]);
    // // Optionally write to a JSON file
    await fs.writeFile(
      path.join(__dirname, 'json/GTCTokenHolders-Dec_16_2024.json'),
      JSON.stringify(filteredData, null, 2)
    );
  } catch (error) {
    console.error('Error:', error);
  }
}

main();
