import https from 'https';
import { execSync } from 'child_process';

const token = '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';
const repoName = 'meeparking';

function githubRequest(path, method = 'GET', data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.github.com',
      path,
      method,
      headers: {
        'Authorization': `token ${token}`,
        'User-Agent': 'MeeParking-Setup',
        'Accept': 'application/vnd.github.v3+json',
      },
    };

    if (data) {
      options.headers['Content-Type'] = 'application/json';
    }

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body || '{}');
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });

    req.on('error', reject);
    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

async function main() {
  console.log('1. Fetching GitHub user profile...');
  const userRes = await githubRequest('/user');
  if (userRes.status !== 200) {
    console.error('Failed to authenticate with GitHub token:', userRes);
    process.exit(1);
  }

  const username = userRes.data.login;
  console.log(`Authenticated as: ${username}`);

  console.log(`2. Creating private repository "${repoName}"...`);
  const createRes = await githubRequest('/user/repos', 'POST', {
    name: repoName,
    description: 'Mee Parking – Smart Parking Marketplace (Flutter Mobile App + React Admin Panel)',
    private: true,
    auto_init: false,
  });

  if (createRes.status === 201) {
    console.log(`Created private repository: ${createRes.data.html_url}`);
  } else if (createRes.status === 422) {
    console.log(`Repository "${repoName}" already exists on GitHub. Continuing with push...`);
  } else {
    console.log('Repo creation response:', createRes);
  }

  console.log('3. Staging and committing files...');
  try {
    execSync('git init', { stdio: 'inherit' });
    execSync('git branch -M main', { stdio: 'inherit' });
    
    // Add remote with token
    const remoteUrl = `https://${token}@github.com/${username}/${repoName}.git`;
    try {
      execSync('git remote remove origin', { stdio: 'ignore' });
    } catch (_) {}
    execSync(`git remote add origin ${remoteUrl}`, { stdio: 'inherit' });

    execSync('git add .', { stdio: 'inherit' });
    try {
      execSync('git commit -m "Initial commit: Complete Mee Parking Mobile App & React Web Admin Panel"', { stdio: 'inherit' });
    } catch (e) {
      console.log('No new changes to commit, proceeding to push...');
    }

    console.log('4. Pushing code to private GitHub repository...');
    execSync('git push -u origin main --force', { stdio: 'inherit' });

    // Clean remote URL to not store token in git config
    execSync(`git remote set-url origin https://github.com/${username}/${repoName}.git`, { stdio: 'inherit' });

    console.log('\n SUCCESS! Private repository created and code pushed:');
    console.log(` https://github.com/${username}/${repoName}`);
  } catch (err) {
    console.error('Error during git execution:', err);
  }
}

main().catch(console.error);
