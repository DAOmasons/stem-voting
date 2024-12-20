import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { getAddress, isAddress } from 'viem';
import fs from 'fs/promises';
import path from 'path';

const MERKLE_ROOT =
  '0xab743e2023cb59fbee44e8db2d954875524c9538e274ebb5b381aa02c39f481f';

function generateVoters(count: number) {
  const voters = [];
  for (let i = 0; i < count; i++) {
    const randomBytes = new Uint8Array(20);
    crypto.getRandomValues(randomBytes);

    const address = getAddress(
      '0x' +
        Array.from(randomBytes)
          .map((b) => b.toString(16).padStart(2, '0'))
          .join('')
    );

    const minWei = 10n ** 17n; // 0.1 ETH
    const maxWei = 10n ** 21n; // 1000 ETH
    const range = maxWei - minWei;
    // const address = `0x${(i + 1).toString(16).padStart(40, '0')}`;
    // const points = Math.floor(Math.random() * 900 + 100).toString();
    // voters.push([address, points]);

    if (isAddress(address) === false) {
      throw new Error(`Invalid address: ${address}`);
    }

    const randomBytes8 = new Uint8Array(8);
    crypto.getRandomValues(randomBytes8);
    const randomValue = BigInt(
      '0x' +
        Array.from(randomBytes8)
          .map((b) => b.toString(16).padStart(2, '0'))
          .join('')
    );

    const balanceInWei = (randomValue % range) + minWei;

    voters.push([address, balanceInWei.toString()]);
  }
  return voters;
}

async function main() {
  // Generate voters
  const voters = generateVoters(6500);

  // Create merkle tree
  const tree = StandardMerkleTree.of(voters, ['address', 'uint256']);
  const root = tree.root;

  // Prepare output data
  const outputData = {
    merkleRoot: root,
    solidityRoot: `bytes32 constant MERKLE_ROOT = ${root};`,
    tree: tree.dump(),
  };

  // Create output directory if it doesn't exist
  const outputDir = path.join(process.cwd(), 'merkle-data');
  await fs.mkdir(outputDir, { recursive: true });

  // Save to files
  await fs.writeFile(
    path.join(outputDir, 'merkle-info.json'),
    JSON.stringify(outputData, null, 2)
  );

  // Log information
  console.log('\nMerkle Root to use in deployment:', root);
  console.log(
    '\nRoot in hex for Solidity:',
    `bytes32 constant MERKLE_ROOT = ${root};`
  );
  console.log('\nData has been saved to merkle-data/merkle-info.json');
}

main().catch(console.error);
